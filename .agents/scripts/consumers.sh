#!/usr/bin/env bash
# consumers.sh — recursively find which hosts reach a registry key or flake input name.
#
# Usage: consumers.sh <name>...
#   name   a flake.modules.{nixos,homeManager} registry key (e.g. desktop-noctalia-home)
#          or a flake input name (e.g. noctalia)
#
# Greps modules/, hosts/, profiles/ for occurrences of "<name>" used as a
# dotted reference (e.g. `nixosModules.<name>`, `homeManagerModules.<name>`,
# `inputs.<name>`), excluding the line(s) that merely *define* the key under
# `flake.modules.nixos.<name>` / `flake.modules.homeManager.<name>`. When a
# consuming file is itself a host file (hosts/<host>/...), that host is
# reported directly. When the consuming file is a module/profile that itself
# registers under other key(s), those keys are recursively resolved until
# host files are reached.
#
# Prints "<host>: via <file>" lines (deduplicated), one per host/file pair.
# This is how the expected-drift set for a given change is derived.
#
# Exit codes: 0 on success (even zero consumers found), 2 on argument error.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: consumers.sh <name>..." >&2
  exit 2
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

declare -A REPORTED
declare -A VISITED
QUEUE=("$@")

find_consumer_files() {
  local name="$1"
  local def_pattern="flake\.modules\.(nixos|homeManager)\.${name}[[:space:]]*="
  local ref_pattern="(?<=\.)${name}(?![A-Za-z0-9_-])"

  grep -rlP "$ref_pattern" modules hosts profiles 2>/dev/null | while read -r f; do
    if grep -P "$def_pattern" "$f" >/dev/null 2>&1; then
      # File defines this key; only report it if it ALSO consumes it elsewhere.
      if grep -P "$ref_pattern" "$f" | grep -vP "$def_pattern" >/dev/null 2>&1; then
        echo "$f"
      fi
    else
      echo "$f"
    fi
  done
}

get_registered_keys() {
  local f="$1"
  grep -oP 'flake\.modules\.(nixos|homeManager)\.[A-Za-z0-9_-]+' "$f" 2>/dev/null \
    | sed -E 's/^flake\.modules\.(nixos|homeManager)\.//' \
    | sort -u
}

while [[ ${#QUEUE[@]} -gt 0 ]]; do
  name="${QUEUE[0]}"
  QUEUE=("${QUEUE[@]:1}")

  if [[ -n "${VISITED[$name]:-}" ]]; then
    continue
  fi
  VISITED[$name]=1

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if [[ "$f" =~ ^hosts/([^/]+)/ ]]; then
      host="${BASH_REMATCH[1]}"
      line="${host}: via ${f}"
      if [[ -z "${REPORTED[$line]:-}" ]]; then
        REPORTED[$line]=1
        echo "$line"
      fi
    else
      while IFS= read -r k; do
        [[ -z "$k" ]] && continue
        QUEUE+=("$k")
      done < <(get_registered_keys "$f")
    fi
  done < <(find_consumer_files "$name")
done
