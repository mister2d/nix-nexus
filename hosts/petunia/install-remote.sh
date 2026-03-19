#!/usr/bin/env bash
# ==============================================================================
# NixOS Install Script — petunia (WITHOUT CLONE / REMOTE FLAKE)
# ==============================================================================
# Use this when you CANNOT or do not want to clone nix-nexus onto the live ISO.
#
# OPTION A — Run directly on the live ISO (repo pulled from GitHub on demand):
#
#   Boot NixOS ISO, get network up, then run ONE of these (as root):
#
#   ✓ CORRECT — script is read from a separate FD, stdin stays as your terminal:
#     sudo bash <(curl -fsSL https://raw.githubusercontent.com/mister2d/nix-nexus/main/hosts/petunia/install-remote.sh)
#
#   ✓ CORRECT — download first, then run:
#     curl -fsSL https://raw.githubusercontent.com/mister2d/nix-nexus/main/hosts/petunia/install-remote.sh -o /tmp/install.sh
#     sudo bash /tmp/install.sh
#
#   ✗ WRONG — do NOT pipe through bash:
#     curl ... | sudo bash   # stdin is the pipe; 'read' prompts break
#
#   NOTE: Requires the GitHub repo to be public, OR that you have authenticated
#   the Nix GitHub fetcher (e.g., via a GITHUB_TOKEN env var or git credentials).
#
# OPTION B — Install FROM another machine over SSH (preferred, no ISO setup):
#
#   On the live ISO:
#     systemctl start sshd
#     passwd root   # set a temporary root password
#
#   From any machine with the repo cloned:
#     nix run nixpkgs#nixos-anywhere -- \
#       --flake .#petunia \
#       root@<ISO_IP>
#
#   nixos-anywhere handles disko partitioning, builds on the SOURCE machine
#   (no ISO OOM), copies closure to the target, and runs nixos-install.
#   The two-step --eval-store trick is NOT needed because nixos-anywhere builds
#   locally and uses nix copy to transfer the result.
#
# ==============================================================================
# This script implements OPTION A.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[BOOTSTRAP] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

[[ $EUID -ne 0 ]] && error "Must be run as root."

# Guard: stdin must be a terminal so that 'read' prompts work correctly.
# 'curl URL | bash' pipes the script through stdin, so 'read' reads script
# lines instead of user input. Use 'bash <(curl URL)' or download first.
if [[ ! -t 0 ]]; then
    echo -e "\033[0;31m[ERROR] stdin is not a terminal — interactive prompts will not work.\033[0m"
    echo
    echo "Run this script using one of these methods instead:"
    echo "  sudo bash <(curl -fsSL <URL>)"
    echo "  curl -fsSL <URL> -o /tmp/install.sh && sudo bash /tmp/install.sh"
    exit 1
fi

# ==============================================================================
# Configuration
# ==============================================================================

TARGET_HOSTNAME="petunia"
TARGET_USER="${TARGET_USER:-ddukes}"
FLAKE_URI="${FLAKE_URI:-github:mister2d/nix-nexus}"

# Disko rev pinned to match flake.lock at time of writing.
# UPDATE THIS when flake.lock pins a new disko revision.
DISKO_REV="${DISKO_REV:-878ec37d6a8f52c6c801d0e2a2ad554c75b9353c}"

# Disk by-id path — stable across reformats, specific to this machine's NVMe.
DISK_BY_ID="nvme-Samsung_SSD_990_EVO_Plus_1TB_S7U5NJ0XB06359F"

echo -e "${BLUE}=== NixOS ${TARGET_HOSTNAME^} Install (remote/no-clone) ===${NC}"
echo "Hostname:  $TARGET_HOSTNAME"
echo "Flake:     $FLAKE_URI"
echo "Disko rev: $DISKO_REV"
echo
echo "NOTE: If the GitHub repo is private, set FLAKE_URI to a reachable URI,"
echo "      e.g.: FLAKE_URI=git+ssh://git@github.com/mister2d/nix-nexus"
echo
read -rp "Proceed? This will DESTROY all data on the target disk. (type 'yes'): " confirm
[[ "$confirm" != "yes" ]] && error "Aborted."

# --- Collect LUKS passphrase ---
echo
log "Enter LUKS passphrase for the encrypted volume."
read -rs -p "  Passphrase: " LUKS_PASS; echo
read -rs -p "  Confirm:    " LUKS_PASS2; echo
[[ "$LUKS_PASS" == "$LUKS_PASS2" ]] || error "Passphrases do not match."
[[ -n "$LUKS_PASS" ]] || error "Passphrase must not be empty."
printf '%s' "$LUKS_PASS" > /tmp/disko-luks-password
unset LUKS_PASS LUKS_PASS2
trap 'rm -f /tmp/disko-luks-password' EXIT

# --- Cleanup ---
log "Tearing down any existing mounts/pools..."
swapoff -a || true
umount -R /mnt 2>/dev/null || true
zpool export -a 2>/dev/null || true
cryptsetup close crypted 2>/dev/null || true

# --- Fetch disko.nix from the remote flake ---
FLAKE_SOURCE=$(nix eval --raw \
    --extra-experimental-features "nix-command flakes" \
    --impure \
    --expr "(builtins.getFlake \"${FLAKE_URI}\").outPath")
DISKO_NIX="$FLAKE_SOURCE/hosts/$TARGET_HOSTNAME/disko.nix"
log "disko.nix resolved at: $DISKO_NIX"

# --- Partitioning (Disko) ---
log "Partitioning via disko (rev ${DISKO_REV::8}...)..."
nix --extra-experimental-features "nix-command flakes" \
    run "github:nix-community/disko/$DISKO_REV" -- \
    --mode disko \
    "$DISKO_NIX"

# --- ZFS ARC cap ---
log "Capping ZFS ARC at 2GB..."
echo 2147483648 > /sys/module/zfs/parameters/zfs_arc_max || true

# --- Step 1: Build system closure into /mnt ---
# Builds to NVMe via --store /mnt (avoids live tmpfs OOM).
# --eval-store auto prevents the derivation-goal.cc assertion on older Nix,
# but the coroutine-based substituter (Goal::Co, Nix ≥2.22) has a separate
# race in builtOutputs tracking. Mitigations: --max-jobs 1 serialises goal
# execution; --option max-substitution-jobs 4 limits concurrent downloads.
# Packages already in /mnt/nix from a prior attempt are reused on retry.
export NIXPKGS_ALLOW_UNFREE=1

BUILD_FLAKE="${FLAKE_URI}#nixosConfigurations.${TARGET_HOSTNAME}.config.system.build.toplevel"
for attempt in 1 2 3; do
    log "Step 1/3: Build attempt $attempt/3 (from $FLAKE_URI)..."
    if nix \
        --extra-experimental-features "nix-command flakes" \
        build \
        --store /mnt \
        --eval-store auto \
        --impure \
        --max-jobs 1 \
        --option max-substitution-jobs 4 \
        --option fallback true \
        --option require-sigs false \
        "$BUILD_FLAKE" \
        --out-link /tmp/nixos-toplevel; then
        break
    fi
    [[ $attempt -eq 3 ]] && error "Build failed after 3 attempts. Check errors above."
    log "Build crashed (likely assertion race). Retrying — packages in /mnt/nix are reused."
done

# --- Step 2: Bridge the store gap ---
log "Step 2/3: Registering /mnt store paths with running Nix daemon..."
nix-store --load-db < <(nix-store --store /mnt --dump-db)

# --- Shallow clone repo into /mnt/etc/nixos ---
# Provides a working copy for future nixos-rebuild on the installed system.
# Skipped if no git credentials are available — user can clone post-install.
log "Attempting shallow clone of repo into /mnt/etc/nixos for future rebuilds..."
mkdir -p /mnt/etc/nixos
if git clone --depth=1 "git@github.com:mister2d/nix-nexus.git" /mnt/etc/nixos 2>/dev/null; then
    log "Repo cloned to /mnt/etc/nixos."
else
    log "Clone skipped (no credentials or network issue)."
    log "POST-INSTALL: clone the repo to /home/$TARGET_USER/workspace/nix-nexus"
    log "  and run: sudo nixos-rebuild switch --flake .#$TARGET_HOSTNAME"
fi

# --- Step 3: Install (profile + bootloader only) ---
TOPLEVEL=$(readlink /tmp/nixos-toplevel)
log "Step 3/3: Installing bootloader and system profile (${TOPLEVEL})..."
if ! nixos-install \
    --system "$TOPLEVEL" \
    --no-root-passwd \
    --no-channel-copy \
    --max-jobs 4; then
    error "nixos-install failed."
fi

log "SUCCESS — ${TARGET_HOSTNAME^} is provisioned. Reboot to enter your new system."
log ""
log "If /mnt/etc/nixos is empty, post-install on the running system:"
log "  git clone git@github.com:mister2d/nix-nexus.git ~/workspace/nix-nexus"
log "  sudo nixos-rebuild switch --flake ~/workspace/nix-nexus#$TARGET_HOSTNAME"
