#!/usr/bin/env bash
# ==============================================================================
# NixOS Install Script — avina (VM Matrix 2.0 Server)
# ==============================================================================
# Adapted from petunia's bare-metal script for VM resource constraints.
# 12GB RAM, 4 Cores.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[BOOTSTRAP] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

[[ $EUID -ne 0 ]] && error "Must be run as root."

TARGET_HOSTNAME="$(basename "$(cd "$(dirname "$0")" && pwd)")"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Pin disko rev from flake.lock
DISKO_REV=$(nix --extra-experimental-features "nix-command flakes" eval --raw --impure \
  --expr "(builtins.fromJSON (builtins.readFile \"$REPO_ROOT/flake.lock\")).nodes.disko.locked.rev")

if zpool list "$TARGET_HOSTNAME" >/dev/null 2>&1; then
    RESUME_MODE=true
    DISKO_MODE="mount"
else
    RESUME_MODE=false
    DISKO_MODE="disko"
fi

echo -e "${BLUE}=== NixOS ${TARGET_HOSTNAME^} Install (${DISKO_MODE^^} mode) ===${NC}"
echo "Hostname:  $TARGET_HOSTNAME"
echo "Repo:      $REPO_ROOT"
echo "Disko rev: $DISKO_REV"
echo

if [ "$RESUME_MODE" = true ]; then
    log "Existing ZFS pool detected. Resuming installation..."
    read -rp "Proceed with resume? (type 'yes'): " confirm
else
    echo -e "${RED}DANGER: No active pool found. This will DESTROY all data on /dev/sda.${NC}"
    read -rp "Proceed with FRESH installation? (type 'yes'): " confirm
fi

[[ "$confirm" != "yes" ]] && error "Aborted."

# --- Cleanup ---
log "Tearing down any existing mounts/pools..."
swapoff -a || true
umount -R /mnt 2>/dev/null || true
zpool export -a 2>/dev/null || true

# --- Partitioning & Mounting (Disko) ---
log "Executing Disko ($DISKO_MODE)..."
nix --extra-experimental-features "nix-command flakes" \
    run "github:nix-community/disko/$DISKO_REV" -- \
    --mode "$DISKO_MODE" \
    "$REPO_ROOT/hosts/$TARGET_HOSTNAME/disko.nix"

# --- Resource Pressure Mitigation (12GB RAM) ---
log "Throttling ZFS ARC to 1GB to preserve RAM for Nix daemon..."
echo 1073741824 > /sys/module/zfs/parameters/zfs_arc_max || true

log "Injecting high resource limits..."
ulimit -n 65536 || true
ulimit -u 16384 || true

# --- Step 1: Build system closure into /mnt ---
log "Step 1/3: Building system closure into target store..."
export NIXPKGS_ALLOW_UNFREE=1

BUILD_FLAKE=".#nixosConfigurations.$TARGET_HOSTNAME.config.system.build.toplevel"
for attempt in 1 2 3; do
    log "Step 1/3: Build attempt $attempt/3..."
    # Constrain to 2 cores to avoid OOM on 12GB RAM during heavy eval/build
    if nix \
        --extra-experimental-features "nix-command flakes" \
        build \
        --store /mnt \
        --eval-store auto \
        --impure \
        --max-jobs 2 \
        --option max-substitution-jobs 4 \
        "$BUILD_FLAKE" \
        --out-link /tmp/nixos-toplevel; then
        break
    fi
    [[ $attempt -eq 3 ]] && error "Build failed after 3 attempts."
    log "Retrying build..."
done

# --- Step 2: Bridge the store gap ---
log "Step 2/3: Registering /mnt store paths..."
nix-store --load-db < <(nix-store --store /mnt --dump-db)

# --- Step 3: Install (profile + bootloader) ---
TOPLEVEL=$(readlink /tmp/nixos-toplevel)
log "Step 3/3: Installing bootloader and system profile (${TOPLEVEL})..."
if ! nixos-install \
    --system "$TOPLEVEL" \
    --no-root-passwd \
    --no-channel-copy \
    --max-jobs 2; then
    error "nixos-install failed."
fi

log "SUCCESS — ${TARGET_HOSTNAME^} is provisioned. Reboot to enter your new system."
