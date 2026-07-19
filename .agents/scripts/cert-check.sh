#!/usr/bin/env bash
# cert-check.sh — verify the ephemeral Vault-issued SSH cert is usable for deploys.
#
# Usage: cert-check.sh [--min-minutes N]
#   --min-minutes N   required remaining validity in minutes (default: 30)
#
# Parses `ssh-keygen -L -f ~/.ssh/id_ed25519-cert.pub`:
#   - Principals must include "root" (this fleet deploys as root@<host>).
#   - The certificate's "Valid" window must have more than N minutes remaining.
#
# On success, prints the remaining minutes and exits 0.
#
# Exit codes: 0 = OK, 20 = expired or expiring within N minutes ("regenerate
# Vault cert"), 21 = wrong principal (root not present), 22 = cert file
# missing or unparseable.

set -euo pipefail

CERT="${HOME}/.ssh/id_ed25519-cert.pub"
MIN_MINUTES=30

while [[ $# -gt 0 ]]; do
  case "$1" in
    --min-minutes)
      MIN_MINUTES="$2"
      shift 2
      ;;
    *)
      echo "Usage: cert-check.sh [--min-minutes N]" >&2
      exit 22
      ;;
  esac
done

if [[ ! -f "$CERT" ]]; then
  echo "cert-check: ${CERT} not found" >&2
  exit 22
fi

INFO="$(ssh-keygen -L -f "$CERT" 2>/dev/null || true)"
if [[ -z "$INFO" ]]; then
  echo "cert-check: failed to parse ${CERT}" >&2
  exit 22
fi

# Principals block looks like:
#         Principals:
#                 root
PRINCIPALS="$(printf '%s\n' "$INFO" | awk '/Principals:/{p=1;next} /^[[:space:]]*[A-Za-z ]+:/{p=0} p' | tr -d '[:space:]')"
if [[ "$PRINCIPALS" != *"root"* ]]; then
  echo "cert-check: principal 'root' not found in ${CERT}" >&2
  exit 21
fi

VALID_LINE="$(printf '%s\n' "$INFO" | grep -m1 'Valid:')"
# "        Valid: from 2026-07-18T22:09:19 to 2026-07-19T06:09:49"
VALID_TO="$(printf '%s\n' "$VALID_LINE" | sed -E 's/.*to ([0-9T:-]+).*/\1/')"

if [[ -z "$VALID_TO" ]]; then
  echo "cert-check: could not parse validity window from: ${VALID_LINE}" >&2
  exit 22
fi

NOW_EPOCH="$(date -u +%s)"
VALID_TO_EPOCH="$(date -u -d "$VALID_TO" +%s 2>/dev/null || true)"

if [[ -z "$VALID_TO_EPOCH" ]]; then
  echo "cert-check: could not convert '${VALID_TO}' to epoch" >&2
  exit 22
fi

REMAINING_MIN=$(( (VALID_TO_EPOCH - NOW_EPOCH) / 60 ))

if [[ "$REMAINING_MIN" -le "$MIN_MINUTES" ]]; then
  echo "cert-check: only ${REMAINING_MIN} minute(s) remaining (< ${MIN_MINUTES}) — regenerate Vault cert" >&2
  exit 20
fi

echo "cert-check: OK, ${REMAINING_MIN} minute(s) remaining (valid to ${VALID_TO})"
exit 0
