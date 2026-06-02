#!/usr/bin/env bash
# Usage: bash .agents/scripts/verify-hosts.sh <phase-label> <host1> [host2 ...]

PHASE="${1:-unknown}"
shift
HOSTS=("$@")
OUTFILE=".agents/SIGNOFF.md"

echo "" >> "$OUTFILE"
echo "### Verification: $PHASE ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> "$OUTFILE"
echo "" >> "$OUTFILE"
echo "| Host | Baseline hash | Post-commit hash | Result |" >> "$OUTFILE"
echo "|---|---|---|---|" >> "$OUTFILE"

for host in "${HOSTS[@]}"; do
  if [[ "$host" == *"@"* ]]; then
    build_path=".#homeConfigurations.\"${host}\".activationPackage"
  else
    build_path=".#nixosConfigurations.${host}.config.system.build.toplevel"
  fi

  new_hash=$(nix derivation show "$build_path" 2>/dev/null \
    | sha256sum | cut -d' ' -f1)
  if [[ -z "$new_hash" ]]; then new_hash="EVAL_FAILURE"; fi

  baseline_hash=$(grep "| ${host} " "$OUTFILE" \
    | grep -v "Verification\|Post-commit\|Result" \
    | head -1 \
    | grep -oP '`\K[a-f0-9]{64}')

  if [[ "$new_hash" == "$baseline_hash" ]]; then
    result="✓ PASS"
  elif [[ -z "$baseline_hash" ]]; then
    result="⚠ NO BASELINE — capture baseline first"
  else
    result="✗ DRIFT — investigate before merge"
  fi

  echo "| $host | \`${baseline_hash:-missing}\` | \`${new_hash}\` | $result |" >> "$OUTFILE"
  echo "$host: $result"
done
