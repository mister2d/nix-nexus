#!/usr/bin/env bash
# NixOS Petunia Bootstrap Script (LUKS + ZFS)
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

# --- Interactive Prompts ---
echo -e "${BLUE}=== NixOS Petunia Installation Setup ===${NC}"

# 1. Disk Selection (Fixed to nvme0n1 based on recon)
DISK="/dev/nvme0n1"
[[ ! -b "$DISK" ]] && error "Device $DISK not found."

# 2. Network & Identity
HOSTNAME="petunia"
USERNAME="ddukes"

# 3. ZFS Parameters (Theme: Hostname)
ZPOOL="petunia"

# 4. Confirmation
echo -e "${RED}DANGER: This will DESTROY all data on $DISK.${NC}"
echo "Hostname: $HOSTNAME"
echo "Username: $USERNAME"
echo "ZFS Pool: $ZPOOL"
echo "Target Disk: $DISK"
echo "Encryption: LUKS (Yes)"
echo
read -rp "Proceed with installation? (type 'yes'): " confirm
[[ "$confirm" != "yes" ]] && error "Aborted by user."

# --- Cleanup ---
log "Cleaning up existing mounts..."
swapoff -a || true
umount -R /mnt 2>/dev/null || true
zpool export "$ZPOOL" 2>/dev/null || true
cryptsetup close crypted 2>/dev/null || true

# --- Partitioning ---
log "Wiping $DISK..."
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"

log "Partitioning $DISK..."
BOOT_PART_LABEL="BOOT"
LUKS_PART_LABEL="DISK_LUKS"

parted "$DISK" -- mklabel gpt
parted "$DISK" -- mkpart "$BOOT_PART_LABEL" fat32 1MiB 1GiB
parted "$DISK" -- set 1 esp on
parted "$DISK" -- mkpart "$LUKS_PART_LABEL" 1GiB 100%

# Inform kernel of partition changes
udevadm settle
sleep 2

BOOT_DEV="/dev/disk/by-partlabel/$BOOT_PART_LABEL"
LUKS_DEV="/dev/disk/by-partlabel/$LUKS_PART_LABEL"

# --- Formatting Boot ---
log "Formatting Boot partition..."
mkfs.vfat -F 32 -n "$BOOT_PART_LABEL" "$BOOT_DEV"

# --- LUKS Setup ---
log "Setting up LUKS Encryption..."
cryptsetup luksFormat --type luks2 --batch-mode "$LUKS_DEV"
cryptsetup open "$LUKS_DEV" crypted

# --- ZFS Setup ---
log "Creating ZFS Pool: $ZPOOL..."
zpool create -f \
    -o ashift=12 \
    -o autotrim=on \
    -O compression=lz4 \
    -O acltype=posixacl \
    -O xattr=sa \
    -O relatime=on \
    -O mountpoint=none \
    "$ZPOOL" /dev/mapper/crypted

log "Creating Datasets..."
zfs create -o mountpoint=legacy "$ZPOOL/root"
zfs snapshot "$ZPOOL/root@blank"
zfs create -o mountpoint=legacy "$ZPOOL/nix"
zfs create -o mountpoint=legacy "$ZPOOL/home"
zfs create -o mountpoint=legacy "$ZPOOL/var"

# Swap (66G for 64GB RAM)
log "Creating Swap ZVOL..."
zfs create -V 66G -b 16k -o compression=zle \
    -o logbias=throughput -o sync=always \
    -o primarycache=metadata -o secondarycache=none \
    -o com.sun:auto-snapshot=false "$ZPOOL/swap"

udevadm settle
sleep 2
mkswap -f "/dev/zvol/$ZPOOL/swap"

# --- Mounting ---
log "Mounting filesystems..."
mount -t zfs "$ZPOOL/root" /mnt
mkdir -p /mnt/{nix,home,var,boot}
mount -t zfs "$ZPOOL/nix" /mnt/nix
mount -t zfs "$ZPOOL/home" /mnt/home
mount -t zfs "$ZPOOL/var" /mnt/var
mount "$BOOT_DEV" /mnt/boot
swapon "/dev/zvol/$ZPOOL/swap"

# --- Installation ---
log "Building NixOS system profile..."
# 1. Ensure the Git tree is clean so Nix sees all files
git add . || true

# 2. Clear any cached failed paths that might trigger the assertion bug
nix-store --clear-failed-paths || true

# 3. Build the system toplevel with --fallback.
# --fallback is CRITICAL here: it tells Nix that if a binary substitute (like libidn2)
# fails its assertion/checksum check, it should attempt to build from source
# instead of core-dumping.
export NIXPKGS_ALLOW_UNFREE=1
nix build ".#nixosConfigurations.$HOSTNAME.config.system.build.toplevel" \
    --extra-experimental-features "nix-command flakes" \
    --impure \
    --fallback \
    --print-out-paths \
    --no-link \
    > /tmp/nixos-toplevel

TOPLEVEL=$(cat /tmp/nixos-toplevel)

log "Executing nixos-install..."
nixos-install --system "$TOPLEVEL" --no-root-passwd

log "SUCCESS! System installed on petunia."
log "Reboot now to enter your new NixOS environment."
