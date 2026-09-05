#!/usr/bin/env bash
# build-host.sh — timed local build of a host's toplevel closure with cache stats.
#
# Usage: build-host.sh <host>
#   host   a NixOS host name from the fleet (see lib.sh NIXOS_HOSTS)
#
# Runs:
#   nix build .#nixosConfigurations.<host>.config.system.build.toplevel \
#     --no-link --print-out-paths
# capturing the build log, and reports:
#   - wall-clock duration
#   - count of derivations substituted (fetched from cache) vs locally built
#   - the resulting store path
#
# Exit codes: 0 = build succeeded, 1 = build failed, 2 = argument error.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: build-host.sh <host>" >&2
  exit 2
fi

HOST="$1"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

START=$(date +%s)
if ! OUT_PATH=$(nix build ".#nixosConfigurations.${HOST}.config.system.build.toplevel" \
  --no-link --print-out-paths 2>"$LOG"); then
  END=$(date +%s)
  echo "build-host: build failed after $((END - START))s."
  cat "$LOG" >&2
  exit 1
fi
END=$(date +%s)

SUBSTITUTED=$(grep -c '^copying path' "$LOG" 2>/dev/null || true)
BUILT=$(grep -c '^building ' "$LOG" 2>/dev/null || true)
SUBSTITUTED="${SUBSTITUTED:-0}"
BUILT="${BUILT:-0}"

echo "build-host: build for ${HOST} finished in $((END - START))s."
echo "  substituted: ${SUBSTITUTED}"
echo "  locally built: ${BUILT}"
echo "  out path: ${OUT_PATH}"
