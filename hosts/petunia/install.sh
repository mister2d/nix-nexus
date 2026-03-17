#!/usr/bin/env bash
# ==============================================================================
# NixOS Declarative Bootstrap Script (Powered by Disko)
# ==============================================================================
# This script orchestrates the transition from a blank disk to a fully 
# provisioned NixOS host. It leverages 'disko' for declarative partitioning 
# and 'nixos-install' for atomic system instantiation.
#
# Usage: Run from a NixOS Installation ISO as root.
# ==============================================================================

set -euo pipefail

# --- Visual Helpers ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[BOOTSTRAP] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

# --- Environment Validation ---
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (or with sudo)."
fi

# --- Identity & Path Resolution ---
# We derive the hostname from the parent directory to allow this script 
# to be portable across different host directories in the nix-nexus.
TARGET_HOSTNAME="$(basename "$(cd "$(dirname "$0")" && pwd)")"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Metadata for the cohesive project story
TARGET_USER="${TARGET_USER:-ddukes}" # Default user if not specified

# --- Interactive Confirmation ---
echo -e "${BLUE}=== NixOS ${TARGET_HOSTNAME^} Declarative Installation ===${NC}"
echo "Hostname: $TARGET_HOSTNAME"
echo "Username: $TARGET_USER"
echo "Method:   Disko (Declarative ZFS-on-LUKS)"
echo "Path:     $REPO_ROOT"
echo
read -rp "Proceed with destroying all data on target disks? (type 'yes'): " confirm
[[ "$confirm" != "yes" ]] && error "Installation aborted by user."

# --- Cleanup Phase ---
# Ensure we start from a clean state by unmounting existing volumes 
# and closing active encryption/ZFS pools.
log "Cleaning up existing mounts and active subsystems..."
swapoff -a || true
umount -R /mnt 2>/dev/null || true
zpool export -a 2>/dev/null || true
cryptsetup close crypted 2>/dev/null || true

# --- Performance & Capacity Tuning ---
# Live ISO environments are RAM-constrained. We expand the writable store 
# capacity to 60GB to prevent "No space left on device" errors during 
# heavy builds (e.g., NVIDIA drivers, complex desktops).
log "Optimizing live store capacity for high-resource build..."
mount -o remount,size=60G /nix/.rw-store

# --- Declarative Partitioning (Disko) ---
# Disko consumes our hosts/${HOSTNAME}/disko.nix definition to atomically
# create partitions, format filesystems (LUKS/ZFS), and mount them to /mnt.
log "Executing Disko: Instantiating declarative storage model..."
nix --experimental-features "nix-command flakes" \
    run github:nix-community/disko -- \
    --mode disko \
    "$REPO_ROOT/hosts/$TARGET_HOSTNAME/disko.nix"

# --- System Instantiation (NixOS Install) ---
log "Executing system build (Installer Store)..."
# We move to the repository root to ensure the flake can be evaluated.
cd "$REPO_ROOT"

# Handle Git ownership and staging. Flakes strictly ignore untracked files.
# We use 'add -A' and 'safe.directory' to ensure the tree is seen as clean by Nix.
git config --global --add safe.directory "$REPO_ROOT" || true
git add -A || true

# We build in the local installer store (tmpfs + NVMe swap) to bypass
# the 'derivation-goal.cc' assertion bug that occurs during cross-store builds.
export NIXPKGS_ALLOW_UNFREE=1
if ! nix build ".#nixosConfigurations.$TARGET_HOSTNAME.config.system.build.toplevel" \
    --extra-experimental-features "nix-command flakes" \
    --impure \
    --option fallback true \
    --no-link \
    --print-out-paths > /tmp/nixos-toplevel; then
    error "NixOS system build failed. Check the error log above."
fi

TOPLEVEL=$(cat /tmp/nixos-toplevel)

log "Executing nixos-install (System Activation)..."
# Now we use the pre-built toplevel. nixos-install will copy the closure to /mnt.
# This avoids the internal build logic that triggers the assertion failure.
if ! nixos-install --system "$TOPLEVEL" --no-root-passwd; then
    error "NixOS installation failed during activation."
fi

# --- Finalization ---
log "SUCCESS! ${TARGET_HOSTNAME^} is fully provisioned."
log "Action required: Reboot now to enter your new NixOS environment."
