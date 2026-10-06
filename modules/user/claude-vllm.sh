# Launches Claude Code against the Bifrost gateway fronting petunia's vLLM server.
# Variables are named BIFROST_* (they target the gateway, not the raw vLLM
# server) so they do not clash with VLLM_* vars such as VLLM_PORT.

usage() {
  cat <<USAGE
Usage: claude-vllm [--env | --help] [claude args...]

  --env    print 'export' lines for the current environment and exit:
             eval "\$(claude-vllm --env)"
  --help   show this message

Anything else is passed to claude. --model is added unless you pass one.

Environment (defaults in brackets):
  BIFROST_HOST [petunia.home.lan]  BIFROST_PORT [8080]
  BIFROST_MODEL [vllm/Qwen3.8-MXFP4]
  BIFROST_AUTH_TOKEN [dummy]
  MAX_THINKING_TOKENS [131072]  CLAUDE_CODE_MAX_CONTEXT_TOKENS [262144]
  CLAUDE_AUTOCOMPACT_PCT_OVERRIDE [80]
USAGE
}

host="${BIFROST_HOST:-petunia.home.lan}"
port="${BIFROST_PORT:-8080}"
model="${BIFROST_MODEL:-vllm/Qwen3.8-MXFP4}"
token="${BIFROST_AUTH_TOKEN:-dummy}"

declare -A claude_env=(
  [ANTHROPIC_BASE_URL]="http://${host}:${port}/anthropic"
  [ANTHROPIC_API_KEY]="$token"
  [ANTHROPIC_AUTH_TOKEN]="$token"
  [MAX_THINKING_TOKENS]="${MAX_THINKING_TOKENS:-131072}"
  [CLAUDE_CODE_MAX_CONTEXT_TOKENS]="${CLAUDE_CODE_MAX_CONTEXT_TOKENS:-262144}"
  [CLAUDE_AUTOCOMPACT_PCT_OVERRIDE]="${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-80}"
  [CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY]="${CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY:-1}"
)

case "${1:-}" in
  --help | -h)
    usage
    exit 0
    ;;
  --env)
    for name in "${!claude_env[@]}"; do
      printf 'export %s=%q\n' "$name" "${claude_env[$name]}"
    done
    exit 0
    ;;
esac

# Warn, but do not abort, when the gateway is unreachable.
if ! timeout 2 bash -c "exec 3<>/dev/tcp/${host}/${port}" 2>/dev/null; then
  echo "warning: Bifrost gateway ${host}:${port} is not reachable" >&2
fi

for name in "${!claude_env[@]}"; do
  export "$name=${claude_env[$name]}"
done

command -v claude >/dev/null || {
  echo "error: 'claude' not found on PATH" >&2
  exit 1
}

for arg in "$@"; do
  case "$arg" in
    --model | --model=*) exec claude "$@" ;;
  esac
done
exec claude --model "$model" "$@"
