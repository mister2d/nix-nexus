#!/usr/bin/env bash
# push-closure.sh — sign a host's running system closure and push it to the internal bincache.
#
# Usage: push-closure.sh <host> [--check-only]
#   host          fleet NixOS host; runs on root@<host>.home.lan
#   --check-only  run only the cert-check and ssh probe, then stop
#
# Pipeline: cert-check.sh -> ssh probe -> on the host: resolve /run/current-system,
# `nix store sign -r` with /run/secrets/builder-key, `nix copy --to` bincache ->
# `nix path-info --store` check that the toplevel is present. The key is only
# referenced by path on the host; its contents never leave it.
#
# Exit codes: 0 = success, 1 = cert-check failed, 2 = ssh unreachable,
# 3 = sign or push failed, 4 = toplevel absent from the cache, 5 = argument error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: push-closure.sh <host> [--check-only]" >&2
  exit 5
fi

HOST="$1"
shift

CHECK_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only)
      CHECK_ONLY=1
      shift
      ;;
    *)
      echo "push-closure: argument '$1' is unknown." >&2
      exit 5
      ;;
  esac
done

CACHE="https://bincache.service.internal.novuscotia.com"
TARGET="root@${HOST}.home.lan"

echo "== push-closure: ${HOST} =="

echo "-- stage: cert-check --"
if ! "${SCRIPT_DIR}/cert-check.sh"; then
  echo "push-closure: cert-check failed. Regenerate the Vault SSH cert, then retry." >&2
  exit 1
fi

echo "-- stage: ssh reachability --"
if ! ssh "$TARGET" true; then
  echo "push-closure: ssh cannot reach ${TARGET}." >&2
  exit 2
fi
echo "ssh reachability: OK"

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  echo "push-closure: --check-only is set. The script stops before signing."
  exit 0
fi

echo "-- stage: sign and push --"
START=$(date +%s)
if ! TOPLEVEL=$(ssh "$TARGET" bash -s -- "$CACHE" <<'REMOTE'
set -euo pipefail
cache="$1"
top="$(readlink -f /run/current-system)"
nix store sign -k /run/secrets/builder-key -r "$top" >&2
nix copy --to "$cache" "$top" >&2
echo "$top"
REMOTE
); then
  echo "push-closure: sign or push failed." >&2
  exit 3
fi
END=$(date +%s)
echo "pushed ${TOPLEVEL} in $((END - START))s"

echo "-- stage: cache check --"
if ! ssh "$TARGET" nix path-info --store "$CACHE" "$TOPLEVEL"; then
  echo "push-closure: ${TOPLEVEL} is absent from the cache." >&2
  exit 4
fi
echo "push-closure: ${HOST} closure is in the cache."
