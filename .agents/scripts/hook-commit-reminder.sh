#!/usr/bin/env bash
# hook-commit-reminder.sh — PostToolUse(Bash) hook: nudge toward closure
# validation after a commit touches evaluated config.
#
# Usage (as a Claude Code hook): reads the PostToolUse hook JSON on stdin
# (schema: https://code.claude.com/docs/en/hooks), extracts .tool_input.command.
#
# Usage (self-test): hook-commit-reminder.sh --test <command-string> [--test-rev <rev>]
#   --test <command-string>   supply the executed command directly, bypassing stdin
#   --test-rev <rev>          inspect this rev's files instead of HEAD
#
# Logic: if the command is not a `git commit` invocation, exit 0 silently. If
# it is, inspect the commit's changed files; if any path matches
# ^(modules/|hosts/|profiles/|flake\.(nix|lock)), exit 2 with a stderr
# reminder to dispatch closure-validator before deploy/push. Otherwise exit 0.
#
# Exit codes: 0 = not a commit, or a commit with no evaluated-config files;
# 2 = commit touches evaluated config (PostToolUse: non-blocking, stderr fed
# back to Claude as a reminder).

set -euo pipefail

REV="HEAD"
COMMAND=""
TEST_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test)
      TEST_MODE=1
      COMMAND="$2"
      shift 2
      ;;
    --test-rev)
      REV="$2"
      shift 2
      ;;
    *)
      echo "Usage: hook-commit-reminder.sh [--test <command-string>] [--test-rev <rev>]" >&2
      exit 3
      ;;
  esac
done

if [[ "$TEST_MODE" -eq 0 ]]; then
  COMMAND="$(jq -r '.tool_input.command // empty')"
fi

if [[ "$COMMAND" != git\ commit* ]]; then
  exit 0
fi

ROOT="$(git rev-parse --show-toplevel)"
CHANGED="$(cd "$ROOT" && git diff-tree --no-commit-id --name-only -r "$REV")"

if echo "$CHANGED" | grep -qE '^(modules/|hosts/|profiles/|flake\.(nix|lock))'; then
  echo "This commit touches evaluated config. Dispatch closure-validator (verify-drift.sh and signoff.sh) before deploy or push." >&2
  exit 2
fi

exit 0
