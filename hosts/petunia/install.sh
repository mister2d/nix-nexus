#!/usr/bin/env bash
# ==============================================================================
# NixOS Install Script — petunia (WITH CLONE)
# ==============================================================================
# Prerequisites: Boot NixOS live ISO, clone the nix-nexus repo, run as root.
#
#   git clone git@github.com:mister2d/nix-nexus.git
#   sudo ./nix-nexus/hosts/petunia/install.sh
#
# For installation WITHOUT cloning the repo on the ISO, see install-remote.sh.
# For installation FROM another machine over SSH, see install-remote.sh.
# ==============================================================================
#
# ARCHITECTURE — why this two-step approach:
#
#   The live ISO's tmpfs cannot hold the full system closure (~43GB). Building
#   directly into /mnt via --store avoids OOM. But nixos-install --flake
#   calls nix build --store /mnt without --eval-store, triggering:
#     nix: derivation-goal.cc:186: Assertion `builtOutputs.count(...) > 0' failed
#   (NOTE: this assertion is fixed in Nix ≥2.18 / NixOS 25.11, but OOM remains.)
#
#   STEP 1: nix build --store /mnt --eval-store auto
#     --store /mnt      → packages land on NVMe, never in live tmpfs (no OOM)
#     --eval-store auto → derivation eval uses running store (/), separate from
#                         build context, preventing the assertion crash
#     --out-link        → symlink target is /nix/store/HASH-... (logical path)
#
#   STEP 2: nix-store --load-db (bridge step)
#     Makes the running Nix daemon aware of all paths registered in /mnt's
#     Nix DB. Without this, nixos-install --system cannot resolve the closure.
#
#   STEP 3: nixos-install --system $TOPLEVEL
#     Receives the pre-built logical path. Detects it already exists in the
#     target store (/mnt), skips rebuild. Only sets up profile + bootloader.
#
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[BOOTSTRAP] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

[[ $EUID -ne 0 ]] && error "Must be run as root."

# Derive hostname from script's parent directory name
TARGET_HOSTNAME="$(basename "$(cd "$(dirname "$0")" && pwd)")"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_USER="${TARGET_USER:-ddukes}"

# Pin disko to the exact rev locked in flake.lock to prevent version skew
DISKO_REV=$(nix eval --raw --impure \
  --expr "(builtins.fromJSON (builtins.readFile \"$REPO_ROOT/flake.lock\")).nodes.disko.locked.rev")

echo -e "${BLUE}=== NixOS ${TARGET_HOSTNAME^} Install (with-clone) ===${NC}"
echo "Hostname:  $TARGET_HOSTNAME"
echo "Repo:      $REPO_ROOT"
echo "Disko rev: $DISKO_REV"
echo
read -rp "Proceed? This will DESTROY all data on the target disk. (type 'yes'): " confirm
[[ "$confirm" != "yes" ]] && error "Aborted."

# --- Cleanup ---
log "Tearing down any existing mounts/pools..."
swapoff -a || true
umount -R /mnt 2>/dev/null || true
zpool export -a 2>/dev/null || true
cryptsetup close crypted 2>/dev/null || true

# --- Partitioning (Disko) ---
# Uses the pinned disko rev to partition, format (LUKS2+ZFS), and mount to /mnt.
log "Partitioning via disko (rev ${DISKO_REV::8}...)..."
nix --extra-experimental-features "nix-command flakes" \
    run "github:nix-community/disko/$DISKO_REV" -- \
    --mode disko \
    "$REPO_ROOT/hosts/$TARGET_HOSTNAME/disko.nix"

# --- ZFS ARC cap ---
# Prevent ZFS from consuming RAM needed by the Nix daemon during the build.
log "Capping ZFS ARC at 2GB..."
echo 2147483648 > /sys/module/zfs/parameters/zfs_arc_max || true

# --- Migrate repo to NVMe ---
# Evaluating a large flake from tmpfs is memory-intensive. Moving it to the
# target ZFS pool offloads that pressure to NVMe.
log "Copying repo to /mnt/etc/nixos (eval will run from NVMe)..."
mkdir -p /mnt/etc/nixos
cp -a "$REPO_ROOT/." /mnt/etc/nixos/
sync

# --- Step 1: Build system closure into /mnt ---
log "Step 1/3: Building system closure into target store..."
cd /mnt/etc/nixos
git config --global --add safe.directory /mnt/etc/nixos || true
git add -A || true

export NIXPKGS_ALLOW_UNFREE=1
if ! nix \
    --extra-experimental-features "nix-command flakes" \
    build \
    --store /mnt \
    --eval-store auto \
    --impure \
    --max-jobs 4 \
    --option fallback true \
    --option require-sigs false \
    ".#nixosConfigurations.$TARGET_HOSTNAME.config.system.build.toplevel" \
    --out-link /tmp/nixos-toplevel; then
    error "System closure build failed. See above for details."
fi

# --- Step 2: Bridge the store gap ---
# After building with --store /mnt, the paths are in /mnt's Nix DB but
# unknown to the running ISO's Nix daemon. nixos-install --system will call
# nix copy against the running store, which would fail without this bridge.
log "Step 2/3: Registering /mnt store paths with running Nix daemon..."
nix-store --load-db < <(nix-store --store /mnt --dump-db)

# --- Step 3: Install (profile + bootloader only, no rebuild) ---
# The out-link symlink target is the logical store path (/nix/store/HASH-...),
# which nixos-install resolves against the target root (/mnt).
TOPLEVEL=$(readlink /tmp/nixos-toplevel)
log "Step 3/3: Installing bootloader and system profile (${TOPLEVEL})..."
if ! nixos-install \
    --system "$TOPLEVEL" \
    --no-root-passwd \
    --no-channel-copy \
    --max-jobs 4; then
    error "nixos-install failed. See above for details."
fi

log "SUCCESS — ${TARGET_HOSTNAME^} is provisioned. Reboot to enter your new system."
