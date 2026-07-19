#!/usr/bin/env bash
# verify-drift.sh — per-config derivation comparison between two clean git revs.
# Replaces the old verify-hosts.sh (deleted).
#
# Usage: verify-drift.sh <base-rev> [new-rev]
#   base-rev   git rev to compare from (required)
#   new-rev    git rev to compare to (default: HEAD)
#
# Prints a markdown table on stdout: | Config | base drv | new drv | Drift |
# This script only reports; it does not judge whether drift is expected —
# pair it with consumers.sh to derive the expected-drift set.
#
# Exit codes: 0 = no drift across any config, 10 = drift found in >=1 config,
# 2 = argument error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [[ $# -lt 1 ]]; then
  echo "Usage: verify-drift.sh <base-rev> [new-rev]" >&2
  exit 2
fi

BASE_REV="$1"
NEW_REV="${2:-HEAD}"

echo "| Config | ${BASE_REV} | ${NEW_REV} | Drift |"
echo "|---|---|---|---|"

DRIFT_FOUND=0

for cfg in $NIXOS_HOSTS $HM_CONFIGS; do
  base_drv=$(drv_at_rev "$BASE_REV" "$cfg")
  new_drv=$(drv_at_rev "$NEW_REV" "$cfg")

  if [[ "$base_drv" == "N/A" || "$new_drv" == "N/A" ]]; then
    status="N/A"
  elif [[ "$base_drv" == "EVAL_FAILURE" || "$new_drv" == "EVAL_FAILURE" ]]; then
    status="EVAL_FAILURE"
    DRIFT_FOUND=1
  elif [[ "$base_drv" == "$new_drv" ]]; then
    status="none"
  else
    status="DRIFT"
    DRIFT_FOUND=1
  fi

  echo "| ${cfg} | \`${base_drv}\` | \`${new_drv}\` | ${status} |"
done

if [[ "$DRIFT_FOUND" -eq 1 ]]; then
  exit 10
fi
exit 0
