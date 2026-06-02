#!/usr/bin/env bash
# Usage: bash .agents/scripts/capture-baseline.sh <phase-label>

PHASE="${1:-unknown}"
OUTFILE=".agents/SIGNOFF.md"

echo "" >> "$OUTFILE"
echo "## Baseline: $PHASE ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> "$OUTFILE"
echo "" >> "$OUTFILE"
echo "| Host | Derivation hash |" >> "$OUTFILE"
echo "|---|---|" >> "$OUTFILE"

NIXOS_HOSTS="sweet16 petunia avina hermes openclaw"
for host in $NIXOS_HOSTS; do
  hash=$(nix derivation show \
    ".#nixosConfigurations.${host}.config.system.build.toplevel" 2>/dev/null \
    | sha256sum | cut -d' ' -f1)
  if [[ -z "$hash" ]]; then hash="EVAL_FAILURE"; fi
  echo "| ${host} (NixOS) | \`${hash}\` |" >> "$OUTFILE"
  echo "Captured: ${host} = ${hash}"
done

HM_HOSTS='groot@dualie groot@forge groot@rk3588'
for cfg in $HM_HOSTS; do
  hash=$(nix derivation show \
    ".#homeConfigurations.\"${cfg}\".activationPackage" 2>/dev/null \
    | sha256sum | cut -d' ' -f1)
  if [[ -z "$hash" ]]; then hash="EVAL_FAILURE"; fi
  echo "| ${cfg} (HM) | \`${hash}\` |" >> "$OUTFILE"
  echo "Captured: ${cfg} = ${hash}"
done

echo "" >> "$OUTFILE"
echo "Git commit at baseline: $(git rev-parse HEAD)" >> "$OUTFILE"
echo "" >> "$OUTFILE"
echo "Baseline written to $OUTFILE"
