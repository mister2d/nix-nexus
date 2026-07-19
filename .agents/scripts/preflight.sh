#!/usr/bin/env bash
# preflight.sh — lint gate: pre-commit hooks then a full flake evaluation.
#
# Usage: preflight.sh <file>...
#   file...   one or more changed files to run pre-commit hooks against
#
# Runs, in order:
#   1. nix develop --command pre-commit run --files <file>...
#   2. nix flake check
# Reports pass/fail per stage. Stops at the first failing stage (pre-commit
# failures are usually auto-fixes that need re-staging; flake check failures
# mean the module tree does not evaluate).
#
# Exit codes: 0 = both stages passed, 1 = pre-commit failed, 2 = flake check
# failed, 3 = argument error.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: preflight.sh <file>..." >&2
  exit 3
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "== preflight: pre-commit =="
if nix develop --command pre-commit run --files "$@"; then
  echo "pre-commit: PASS"
else
  echo "pre-commit: FAIL"
  exit 1
fi

echo "== preflight: nix flake check =="
if nix flake check; then
  echo "flake check: PASS"
else
  echo "flake check: FAIL"
  exit 2
fi

echo "preflight: PASS"
