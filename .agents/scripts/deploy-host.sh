#!/usr/bin/env bash
# deploy-host.sh — uniform remote deploy pipeline for any fleet host.
#
# Usage: deploy-host.sh <host> [--build-host <h>] [--boot|--test] [--check-only]
#   host          fleet hostname; deploys as root@<host>.home.lan
#   --build-host  offload the build to root@<h> via nixos-rebuild --build-host
#   --boot        pass "boot" instead of the default "switch" action
#   --test        pass "test" instead of the default "switch" action
#   --check-only  run only the cert-check and ssh-reachability stages, then
#                 stop — never invokes nixos-rebuild
#
# Pipeline: cert-check.sh -> ssh reachability probe (`ssh root@<host>.home.lan
# true`) -> [unless --check-only] `nixos-rebuild <action> --flake .#<host>
# --target-host root@<host>.home.lan` (+ --build-host root@<h> if given) ->
# verify-generation.sh. Timed; prints the resulting generation + toplevel.
#
# All deploys are remote — no local sudo. Auth is the ephemeral Vault SSH
# cert; on cert failure this script stops and reports, it never works around
# auth (see AGENTS.md deployment model notes).
#
# Exit codes: 0 = success, 1 = cert-check failed, 2 = ssh unreachable,
# 3 = nixos-rebuild failed, 4 = generation verify failed, 5 = argument error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: deploy-host.sh <host> [--build-host <h>] [--boot|--test] [--check-only]" >&2
  exit 5
fi

HOST="$1"
shift

BUILD_HOST=""
ACTION="switch"
CHECK_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-host)
      BUILD_HOST="$2"
      shift 2
      ;;
    --boot)
      ACTION="boot"
      shift
      ;;
    --test)
      ACTION="test"
      shift
      ;;
    --check-only)
      CHECK_ONLY=1
      shift
      ;;
    *)
      echo "deploy-host: unknown argument '$1'" >&2
      exit 5
      ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

TARGET="root@${HOST}.home.lan"

echo "== deploy-host: ${HOST} (action=${ACTION}) =="

echo "-- stage: cert-check --"
if ! "${SCRIPT_DIR}/cert-check.sh"; then
  echo "deploy-host: cert-check failed — regenerate the Vault SSH cert before retrying" >&2
  exit 1
fi

echo "-- stage: ssh reachability --"
if ! ssh "$TARGET" true; then
  echo "deploy-host: ${TARGET} unreachable over ssh" >&2
  exit 2
fi
echo "ssh reachability: OK"

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  echo "deploy-host: --check-only, stopping before nixos-rebuild"
  exit 0
fi

CMD=(nixos-rebuild "$ACTION" --flake ".#${HOST}" --target-host "$TARGET")
if [[ -n "$BUILD_HOST" ]]; then
  CMD+=(--build-host "root@${BUILD_HOST}")
fi

echo "-- stage: nixos-rebuild (${CMD[*]}) --"
START=$(date +%s)
if ! "${CMD[@]}"; then
  echo "deploy-host: nixos-rebuild failed" >&2
  exit 3
fi
END=$(date +%s)
echo "nixos-rebuild: OK in $((END - START))s"

echo "-- stage: verify-generation --"
if ! "${SCRIPT_DIR}/verify-generation.sh" "$HOST"; then
  echo "deploy-host: generation verify failed" >&2
  exit 4
fi

echo "deploy-host: ${HOST} deployed successfully in $((END - START))s"
