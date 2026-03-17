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

# --- Memory Pressure Mitigation ---
# ZFS ARC can expand and starve the Nix daemon of memory during massive 
# downloads. We cap the ARC at 2GB during the installation phase.
log "Throttling ZFS ARC to 2GB to preserve RAM for Nix daemon..."
echo 2147483648 > /sys/module/zfs/parameters/zfs_arc_max || true

# --- Configuration Migration ---
# Evaluating a flake from RAM (/root/nix-nexus) creates significant memory 
# overhead. By migrating the configuration to the target ZFS pool, we 
# offload memory pressure to the physical disk.
log "Migrating configuration to target disk (/mnt/etc/nixos)..."
mkdir -p /mnt/etc/nixos
cp -a "$REPO_ROOT/." /mnt/etc/nixos/
sync

# --- System Instantiation (NixOS Install) ---
log "Executing native NixOS installation from ZFS disk..."
# We move into the target disk repo to ensure the flake is evaluated from ZFS.
cd /mnt/etc/nixos

# Handle Git ownership and staging for the new path.
git config --global --add safe.directory /mnt/etc/nixos || true
git add -A || true

# Using the native 'nixos-install --flake' is the most robust way to bootstrap.
# It handles building directly into the target store (/mnt/nix/store).
#
# --max-jobs 1: Crucial for stability on the live ISO to prevent OOM.
# --option fallback true: Ensures we build from source if a binary cache is flaky.
export NIXPKGS_ALLOW_UNFREE=1
if ! nixos-install --flake ".#$TARGET_HOSTNAME" \
    --no-root-passwd \
    --max-jobs 1 \
    --option fallback true; then
    error "NixOS installation failed. Check the error log above."
fi

# --- Finalization ---
log "SUCCESS! ${TARGET_HOSTNAME^} is fully provisioned."
log "Action required: Reboot now to enter your new NixOS environment."
