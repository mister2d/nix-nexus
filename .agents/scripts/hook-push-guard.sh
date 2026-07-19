#!/usr/bin/env bash
# hook-push-guard.sh — PreToolUse(Bash) hook: block `git push` when outgoing
# commits touch evaluated config without a SIGNOFF.md entry in the same range.
#
# Usage (as a Claude Code hook): reads the PreToolUse hook JSON on stdin
# (schema: https://code.claude.com/docs/en/hooks), extracts .tool_input.command.
#
# Usage (self-test):
#   hook-push-guard.sh --test <command-string> [--test-range <A..B>]
#   --test <command-string>   supply the executed command directly, bypassing stdin
#   --test-range <A..B>       use this range instead of resolving @{push}/@{u}
#
# Logic: if the command is not a `git push`, exit 0. Otherwise determine the
# outgoing commit range (@{push}..HEAD, falling back to @{u}..HEAD, falling
# back to origin/main..HEAD; if none resolvable, exit 0 fail-open). If any
# commit in range touches ^(modules/|hosts/|profiles/|flake\.(nix|lock)) AND
# no commit in range touches .agents/SIGNOFF.md, exit 2 with a stderr message.
# Any git failure while probing the range fails open (exit 0) — this hook
# never blocks a push due to its own error.
#
# Exit codes: 0 = not a push, range unresolvable, no evaluated-config drift,
# or a probing error (fail-open); 2 = evaluated-config commits outgoing
# without a SIGNOFF entry (PreToolUse: blocking, stderr fed back to Claude).

set -euo pipefail

RANGE=""
COMMAND=""
TEST_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test)
      TEST_MODE=1
      COMMAND="$2"
      shift 2
      ;;
    --test-range)
      RANGE="$2"
      shift 2
      ;;
    *)
      echo "Usage: hook-push-guard.sh [--test <command-string>] [--test-range <A..B>]" >&2
      exit 3
      ;;
  esac
done

if [[ "$TEST_MODE" -eq 0 ]]; then
  COMMAND="$(jq -r '.tool_input.command // empty')"
fi

if [[ "$COMMAND" != git\ push* ]]; then
  exit 0
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT" || exit 0

if [[ -z "$RANGE" ]]; then
  if git rev-parse '@{push}' >/dev/null 2>&1; then
    RANGE='@{push}..HEAD'
  elif git rev-parse '@{u}' >/dev/null 2>&1; then
    RANGE='@{u}..HEAD'
  elif git rev-parse 'origin/main' >/dev/null 2>&1; then
    RANGE='origin/main..HEAD'
  else
    exit 0
  fi
fi

OUTGOING="$(git rev-list "$RANGE" 2>/dev/null)" || exit 0
if [[ -z "$OUTGOING" ]]; then
  exit 0
fi

CHANGED="$(git diff --name-only "$RANGE" 2>/dev/null)" || exit 0

TOUCHES_CONFIG=0
if echo "$CHANGED" | grep -qE '^(modules/|hosts/|profiles/|flake\.(nix|lock))'; then
  TOUCHES_CONFIG=1
fi

if [[ "$TOUCHES_CONFIG" -eq 0 ]]; then
  exit 0
fi

HAS_SIGNOFF=0
if echo "$CHANGED" | grep -qE '^\.agents/SIGNOFF\.md$'; then
  HAS_SIGNOFF=1
fi

if [[ "$HAS_SIGNOFF" -eq 0 ]]; then
  echo "push blocked — evaluated-config commits lack a SIGNOFF entry; run closure-validator, then retry" >&2
  exit 2
fi

exit 0
