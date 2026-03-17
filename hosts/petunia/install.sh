#!/usr/bin/env bash
# NixOS Petunia Bootstrap Script (Declarative via Disko)
# Optimized for Ryzen 5600X + RTX 3080 Desktop.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[BOOTSTRAP] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

# Root check
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root."
fi

# --- Identity ---
HOSTNAME="petunia"
USERNAME="ddukes"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# --- Interactive Prompts ---
echo -e "${BLUE}=== NixOS Petunia Declarative Installation ===${NC}"
echo "Hostname: $HOSTNAME"
echo "Username: $USERNAME"
echo "Method: Disko (Declarative ZFS-on-LUKS)"
echo
read -rp "Proceed with installation? (type 'yes'): " confirm
[[ "$confirm" != "yes" ]] && error "Aborted by user."

# --- Cleanup ---
log "Cleaning up existing mounts..."
swapoff -a || true
umount -R /mnt 2>/dev/null || true
# Specific to ZFS
zpool export -a 2>/dev/null || true
cryptsetup close crypted 2>/dev/null || true

# --- Store Optimization ---
log "Optimizing live store for large build..."
# Resize the writable part of the Nix store to 60G to handle large builds
# This uses the available RAM/Swap in the live environment.
mount -o remount,size=60G /nix/.rw-store

# --- Disko Execution ---
log "Executing Disko (Partitioning, Formatting, Mounting)..."
# We run disko directly from the flake to ensure it uses our declarative definition.
# This handles LUKS, ZFS, Datasets, and Mounts to /mnt.
nix --experimental-features "nix-command flakes" \
    run github:nix-community/disko -- \
    --mode disko \
    "$REPO_ROOT/hosts/$HOSTNAME/disko.nix"

# --- Installation ---
log "Executing native NixOS installation..."
cd "$REPO_ROOT"

# Ensure the Git tree is clean so Nix sees all files (Disko + HM configs)
git add . || true

# Run the native install command using the flake.
# Using --max-jobs 1 and fallback options for stability on complex builds.
export NIXPKGS_ALLOW_UNFREE=1
if ! nixos-install --flake ".#$HOSTNAME" \
    --no-root-passwd \
    --max-jobs 1 \
    --option fallback true; then
    error "NixOS installation failed. Check the error messages above."
fi

log "SUCCESS! System installed on petunia."
log "Reboot now to enter your new NixOS environment."
