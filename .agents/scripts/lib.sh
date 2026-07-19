#!/usr/bin/env bash
# lib.sh — shared helpers for .agents/scripts/*.sh. Sourced only, not executed.
#
# Provides:
#   NIXOS_HOSTS, HM_CONFIGS       — the fleet lists, defined in exactly one place
#   is_na_config <cfg>            — true if <cfg> is not evaluable on this arch (rk3588/aarch64)
#   installable_for <cfg>         — prints the flake installable attr path for a host or "user@host" HM config
#   drv_at_rev <rev> <cfg>        — clean per-rev eval: prints the .drv store path, or EVAL_FAILURE, or N/A
#
# This file has no shebang execution contract; `source` it from other scripts.

NIXOS_HOSTS="sweet16 petunia avina hermes"
HM_CONFIGS="groot@dualie groot@forge groot@rk3588"

# is_na_config <cfg> — 0 (true) if this config is known-unevaluable on the current arch
is_na_config() {
  local cfg="$1"
  if [[ "$cfg" == "groot@rk3588" && "$(uname -m)" != "aarch64" ]]; then
    return 0
  fi
  return 1
}

# installable_for <cfg> — prints the bare flake attrpath (no installable prefix) for a host or HM config
installable_for() {
  local cfg="$1"
  if [[ "$cfg" == *"@"* ]]; then
    printf 'homeConfigurations."%s".activationPackage' "$cfg"
  else
    printf 'nixosConfigurations.%s.config.system.build.toplevel' "$cfg"
  fi
}

# drv_at_rev <rev> <cfg> — clean git+file per-rev eval; prints a .drv store path,
# "N/A" for known-unevaluable configs, or "EVAL_FAILURE" on real errors.
drv_at_rev() {
  local rev="$1"
  local cfg="$2"

  if is_na_config "$cfg"; then
    echo "N/A"
    return 0
  fi

  local sha
  if ! sha=$(git rev-parse "$rev" 2>/dev/null); then
    echo "EVAL_FAILURE"
    return 0
  fi

  local attr
  attr=$(installable_for "$cfg")

  local out
  if ! out=$(nix path-info --derivation "git+file:${PWD}?rev=${sha}#${attr}" 2>/dev/null); then
    echo "EVAL_FAILURE"
    return 0
  fi

  if [[ -z "$out" ]]; then
    echo "EVAL_FAILURE"
    return 0
  fi

  echo "$out"
}
