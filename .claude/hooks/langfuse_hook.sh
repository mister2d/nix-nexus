#!/usr/bin/env bash
# langfuse_hook.sh — resolves a python3 with the langfuse SDK for
# langfuse_hook.py. Claude Code runs Stop hooks under the session's own
# /bin/sh environment, which has no python3 on this fleet; this wrapper
# falls back through an ambient interpreter, a direnv-cached devshell, and
# finally `nix develop` before giving up.
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$HOOK_DIR/../.." && pwd)}"
STATE_DIR="$HOME/.claude/state"
LOG_FILE="$STATE_DIR/langfuse_hook.log"
HOOK_PY="$HOOK_DIR/langfuse_hook.py"

[ "${TRACE_TO_LANGFUSE:-}" = "true" ] || exit 0

log() {
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  printf '%s [WARN] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG_FILE" 2>/dev/null || true
}

# Buffer the Stop-event payload once; whichever resolver below succeeds
# replays it to langfuse_hook.py unchanged.
PAYLOAD="$(cat)"

if command -v python3 >/dev/null 2>&1 && python3 -c "import langfuse" >/dev/null 2>&1; then
  exec python3 "$HOOK_PY" <<<"$PAYLOAD"
fi

if command -v direnv >/dev/null 2>&1 \
  && direnv exec "$PROJECT_DIR" python3 -c "import langfuse" >/dev/null 2>&1; then
  exec direnv exec "$PROJECT_DIR" python3 "$HOOK_PY" <<<"$PAYLOAD"
fi

if command -v nix >/dev/null 2>&1; then
  exec nix develop "$PROJECT_DIR" --command python3 "$HOOK_PY" <<<"$PAYLOAD"
fi

log "no python3 with langfuse found (checked PATH, direnv, nix develop); skipping trace"
exit 0
