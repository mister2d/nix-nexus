#!/usr/bin/env bash
# lock-diff.sh — node-by-node flake.lock diff between two git revs, via jq.
#
# Usage: lock-diff.sh <old-rev> <new-rev>
#
# Compares every node's "locked" object (rev, or narHash/path for non-rev
# inputs) between flake.lock at old-rev and new-rev. Prints one line per
# changed node:
#   node old-value → new-value
# Added/removed nodes are reported as "(absent) → value" / "value → (absent)".
#
# Exit codes: 0 = no nodes changed, 10 = one or more nodes changed,
# 2 = argument error or flake.lock missing at one of the revs.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: lock-diff.sh <old-rev> <new-rev>" >&2
  exit 2
fi

OLD_REV="$1"
NEW_REV="$2"

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

node_id() {
  local rev="$1" node="$2"
  git show "${rev}:flake.lock" 2>/dev/null \
    | jq -r --arg n "$node" '
        .nodes[$n].locked
        | if .rev then .rev
          elif .narHash then .narHash
          else (. | tostring)
          end
      ' 2>/dev/null || true
}

if ! git show "${OLD_REV}:flake.lock" >/dev/null 2>&1; then
  echo "flake.lock missing at ${OLD_REV}" >&2
  exit 2
fi
if ! git show "${NEW_REV}:flake.lock" >/dev/null 2>&1; then
  echo "flake.lock missing at ${NEW_REV}" >&2
  exit 2
fi

OLD_NODES=$(git show "${OLD_REV}:flake.lock" | jq -r '.nodes | keys[]')
NEW_NODES=$(git show "${NEW_REV}:flake.lock" | jq -r '.nodes | keys[]')
ALL_NODES=$(printf '%s\n%s\n' "$OLD_NODES" "$NEW_NODES" | sort -u)

CHANGED=0
for node in $ALL_NODES; do
  [[ "$node" == "root" ]] && continue
  old_val=$(node_id "$OLD_REV" "$node")
  new_val=$(node_id "$NEW_REV" "$node")

  [[ -z "$old_val" ]] && old_val="(absent)"
  [[ -z "$new_val" ]] && new_val="(absent)"

  if [[ "$old_val" != "$new_val" ]]; then
    echo "${node} ${old_val} → ${new_val}"
    CHANGED=1
  fi
done

if [[ "$CHANGED" -eq 1 ]]; then
  exit 10
fi
exit 0
