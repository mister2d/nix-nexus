#!/usr/bin/env bash
# verify-generation.sh — check a remote host's current system profile.
#
# Usage: verify-generation.sh <host> [toplevel]
#   host       fleet hostname; connects to root@<host>.home.lan
#   toplevel   expected /nix/store/...-nixos-system-... path; if omitted,
#              just reports the current profile without judging it
#
# Via ssh root@<host>.home.lan: resolves /run/current-system and reads the
# active generation number from `nixos-rebuild list-generations` (or
# /nix/var/nix/profiles/system-*-link if unavailable).
#
# Prints "OK" if toplevel is given and matches, "MISMATCH" if given and
# different, or just reports current state if toplevel is omitted.
#
# Exit codes: 0 = OK (or report-only mode succeeded), 1 = MISMATCH,
# 2 = argument error, 3 = ssh/remote failure.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: verify-generation.sh <host> [toplevel]" >&2
  exit 2
fi

HOST="$1"
EXPECTED_TOPLEVEL="${2:-}"
TARGET="root@${HOST}.home.lan"

CURRENT="$(ssh "$TARGET" readlink -f /run/current-system 2>/dev/null || true)"
if [[ -z "$CURRENT" ]]; then
  echo "verify-generation: cannot read /run/current-system on ${TARGET}." >&2
  exit 3
fi

GEN="$(ssh "$TARGET" 'readlink /nix/var/nix/profiles/system' 2>/dev/null || true)"

echo "verify-generation: ${HOST}"
echo "  current system: ${CURRENT}"
[[ -n "$GEN" ]] && echo "  profile link: ${GEN}"

if [[ -z "$EXPECTED_TOPLEVEL" ]]; then
  echo "  (no expected toplevel given, reporting only)"
  exit 0
fi

if [[ "$CURRENT" == "$EXPECTED_TOPLEVEL" ]]; then
  echo "  OK: matches expected toplevel"
  exit 0
else
  echo "  MISMATCH: expected ${EXPECTED_TOPLEVEL}"
  exit 1
fi
