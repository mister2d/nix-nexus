# Petunia: Host-Specific Operations

Petunia is an x86_64 NixOS workstation (AMD Ryzen 5600X, dual R9700, Samsung 990 EVO Plus 1TB NVMe)
running a CachyOS server kernel with LUKS2-on-ZFS full-disk encryption.

---

## TPM2 Auto-Unlock (LUKS2)

Petunia uses TPM2 to unseal the LUKS2 keyslot at boot. No passphrase is needed, so reboots run
unattended. The token sits in the LUKS2 header at keyslot 1. Keyslot 0 keeps the passphrase as
a fallback.

### Current state

- **PCR binding:** PCR 0 (UEFI firmware measurement). Secure Boot is not active on this board.
  PCR 7 (Secure Boot state) stays static and zeroed, so it gives no useful binding.
- **Re-enrollment trigger:** Any UEFI firmware update changes PCR 0. Re-enroll after every
  BIOS update (see below).
- **NixOS modules:** `security.tpm2.*` and `boot.initrd.systemd.tpm2.enable` in
  `modules/core/tpm2.nix`.

### Device path note

`/dev/disk/by-partlabel/DISK_LUKS` does **not** resolve from userspace. Disko creates the GPT
label `disk-main-DISK_LUKS` instead. Always reference the partition directly:

```
/dev/nvme0n1p2
```

### Verify current enrollment

```bash
systemd-cryptenroll /dev/nvme0n1p2
# Expected output:
# SLOT TYPE
#    0 password
#    1 tpm2
```

### Re-enroll after a UEFI firmware update

```bash
# Remove the old TPM2 token
systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p2

# Enroll a new token bound to the new firmware measurement
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0 /dev/nvme0n1p2
```

### Verify auto-unlock after reboot

```bash
journalctl -b | grep -i 'cryptsetup\|tpm'
# "Finished Cryptography Setup for crypted." with no passphrase prompt = success
```

---

## Dual R9700 GPU Setup

Petunia has two physically identical RDNA4 R9700 GPUs. `modules/hardware/petunia/rdna4.nix`
wires both cards into ROCm/HIP. This file holds the full graphics and compute config: amdgpu
KMS, kernel params, the ROCm runtime, the `/opt/rocm` symlink, LACT, and diagnostics.
The HIP/Vulkan build toolchain stays out of the system closure. Inference projects pull
`github:tenarches/nix-rdna4` devShells (`llama-rocm` and `llama-vulkan`) directly instead.

Key settings in `rdna4.nix`:
- `ROCR_VISIBLE_DEVICES=0,1`
- `HCC_AMDGPU_TARGET=gfx1201,gfx1201`
- `pcie_bus_config=performance` kernel param. This raises inter-GPU DMA throughput on the
  X570 x8/x8 link.

### Verify both GPUs visible

```bash
lspci -vv | grep -A5 "VGA\|3D"
rocminfo | grep -A3 "Agent "   # should list two gfx1201 agents
```

---

## Rebuild procedure

Petunia builds itself. Push to GitHub first, then run the rebuild on the host.

```bash
# On your workstation:
git push origin main

# On petunia (in tmux):
time nixos-rebuild switch --flake github:mister2d/nix-nexus#petunia
```

Typical build times: 75s–70s for config-only changes. Builds take longer when new packages
need fetching.
