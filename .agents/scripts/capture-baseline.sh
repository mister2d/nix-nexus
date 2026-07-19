#!/usr/bin/env bash
# capture-baseline.sh — record per-config derivation store paths at a clean git rev.
#
# Usage: capture-baseline.sh <label> [rev] [--outfile PATH]
#   label     free-text label for this baseline, recorded in the SIGNOFF.md block
#   rev       git rev to evaluate at (default: HEAD); must be a clean, committed rev
#   --outfile redirect the appended block to PATH instead of .agents/SIGNOFF.md
#             (also settable via the OUTFILE env var; flag wins over env var)
#
# Appends a "## Baseline: <label> (<timestamp>)" block to OUTFILE in the format
# already used in .agents/SIGNOFF.md, and prints the same table to stdout.
#
# Evaluation is via lib.sh's drv_at_rev (clean git+file?rev= eval, never the
# dirty working tree). EVAL_FAILURE marks a genuine eval error; N/A marks a
# known-unevaluable config (rk3588/aarch64 on non-aarch64 hosts).
#
# Exit codes: 0 always, unless argument parsing fails (2) or OUTFILE cannot be
# written (1). This script does not judge results — it only records them.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"

OUTFILE="${OUTFILE:-.agents/SIGNOFF.md}"

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --outfile)
      OUTFILE="$2"
      shift 2
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done
set -- "${POSITIONAL[@]}"

LABEL="${1:-unknown}"
REV="${2:-HEAD}"

RESOLVED_SHA="$(git rev-parse "$REV")"

{
  echo ""
  echo "## Baseline: $LABEL ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
  echo ""
  echo "| Host | Derivation |"
  echo "|---|---|"
} >> "$OUTFILE"

echo "Baseline: $LABEL @ $RESOLVED_SHA"
printf '%-20s %s\n' "Config" "Derivation"

for host in $NIXOS_HOSTS; do
  drv=$(drv_at_rev "$REV" "$host")
  echo "| ${host} (NixOS) | \`${drv}\` |" >> "$OUTFILE"
  printf '%-20s %s\n' "${host} (NixOS)" "$drv"
done

for cfg in $HM_CONFIGS; do
  drv=$(drv_at_rev "$REV" "$cfg")
  echo "| ${cfg} (HM) | \`${drv}\` |" >> "$OUTFILE"
  printf '%-20s %s\n' "${cfg} (HM)" "$drv"
done

{
  echo ""
  echo "Git commit at baseline: $RESOLVED_SHA"
  echo ""
} >> "$OUTFILE"

echo "Baseline written to $OUTFILE"
