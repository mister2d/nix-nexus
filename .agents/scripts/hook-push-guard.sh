#!/usr/bin/env bash
# hook-push-guard.sh — PreToolUse(Bash) hook: block `git push` when outgoing
# commits touch evaluated config without a sign-off record in the same range.
#
# Usage (as a Claude Code hook): reads the PreToolUse hook JSON on stdin
# (schema: https://code.claude.com/docs/en/hooks), extracts .tool_input.command.
#
# Usage (self-test):
#   hook-push-guard.sh --test <command-string> [--test-range <A..B>] [--test-through <sha>]
#   --test <command-string>   supply the executed command directly, bypassing stdin
#   --test-range <A..B>       use this range instead of resolving @{push}/@{u}
#   --test-through <sha>      use this as signed_off_through instead of reading
#                             .agents/baseline.json at HEAD
#
# Logic: if the command is not a `git push`, exit 0. Otherwise determine the
# outgoing commit range (@{push}..HEAD, falling back to @{u}..HEAD, falling
# back to origin/main..HEAD; if none resolvable, exit 0 fail-open). Collect the
# commits in range that touch modules/, hosts/, profiles/, flake.nix or
# flake.lock; if there are none, exit 0. Otherwise read .signed_off_through
# from .agents/baseline.json **as committed at HEAD** and require every one of
# those commits to be an ancestor of it.
#
# This checks coverage, not mere presence. The previous version only tested
# whether a sign-off file appeared anywhere in the range, which a sign-off
# written for an *earlier* commit satisfied — see 282c8d9..6c83f42 in this
# repo's history, where a config commit shipped unvalidated.
#
# A sign-off never names its own sha: signed_off_through is the head it
# validated, i.e. its own parent. Sign-off commits touch only .agents/, so they
# never appear in the config set and never need covering.
#
# Fail-open ledger — this hook must never block a push due to its own error:
#
#   not a `git push`; unresolvable or empty range              -> 0
#   jq absent; git rev-list/rev-parse/merge-base failure       -> 0
#   signed_off_through names a sha not present in this repo    -> 0
#   no config-touching commits outgoing                        -> 0
#   baseline.json absent or malformed at HEAD                  -> 2  (blocks)
#   >=1 config commit provably not an ancestor of the sign-off -> 2  (blocks)
#
# The absent/malformed-baseline case blocks rather than failing open by
# deliberate choice: absence of the record is precisely the gated condition,
# so failing open there would make the gate defeatable with `rm`.
#
# Exit codes: 0 = allowed (see ledger); 2 = blocked (PreToolUse: blocking,
# stderr fed back to Claude); 3 = bad arguments to the script itself.

set -euo pipefail

RANGE=""
COMMAND=""
TEST_MODE=0
TEST_THROUGH=""

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
    --test-through)
      TEST_THROUGH="$2"
      shift 2
      ;;
    *)
      echo "Usage: hook-push-guard.sh [--test <command-string>] [--test-range <A..B>] [--test-through <sha>]" >&2
      exit 3
      ;;
  esac
done

# No jq means we cannot read the hook payload or the baseline — fail open.
command -v jq >/dev/null 2>&1 || exit 0

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

# Which outgoing commits actually touch evaluated config?
CONFIG_COMMITS="$(git rev-list "$RANGE" -- modules hosts profiles flake.nix flake.lock 2>/dev/null)" || exit 0
if [[ -z "$CONFIG_COMMITS" ]]; then
  exit 0
fi

# What has been signed off? Read the committed tree, never the worktree —
# an uncommitted baseline.json must not satisfy the gate.
if [[ -n "$TEST_THROUGH" ]]; then
  THROUGH="$TEST_THROUGH"
else
  if ! BASELINE="$(git show HEAD:.agents/baseline.json 2>/dev/null)"; then
    echo "push blocked — no .agents/baseline.json committed at HEAD; run closure-validator, then retry" >&2
    exit 2
  fi
  if ! THROUGH="$(printf '%s' "$BASELINE" | jq -er '.signed_off_through // empty' 2>/dev/null)"; then
    echo "push blocked — .agents/baseline.json has no .signed_off_through; run closure-validator, then retry" >&2
    exit 2
  fi
fi

# A sha we cannot resolve is our problem, not the user's.
git cat-file -e "${THROUGH}^{commit}" 2>/dev/null || exit 0

UNCOVERED=""
while IFS= read -r c; do
  [[ -z "$c" ]] && continue
  # --is-ancestor: 0 = ancestor, 1 = not an ancestor, >1 = real git error.
  # Collapsing 1 and >1 would turn a broken repo into a spurious block.
  rc=0
  git merge-base --is-ancestor "$c" "$THROUGH" 2>/dev/null || rc=$?
  case "$rc" in
    0) : ;;
    1) UNCOVERED="$UNCOVERED $c" ;;
    *) exit 0 ;;
  esac
done <<< "$CONFIG_COMMITS"

if [[ -n "$UNCOVERED" ]]; then
  echo "push blocked — config commits not covered by the latest sign-off (signed off through ${THROUGH:0:7}):" >&2
  for c in $UNCOVERED; do
    git log -1 --format='  %h %s' "$c" >&2 || true
  done
  echo "run closure-validator, then retry" >&2
  exit 2
fi

exit 0
