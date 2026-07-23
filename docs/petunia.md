# Petunia: Host-Specific Operations

Petunia is an x86_64 NixOS workstation (AMD Ryzen 5600X, dual R9700, Samsung 990 EVO Plus 1TB NVMe)
running a CachyOS server kernel with LUKS2-on-ZFS full-disk encryption.

---

## TPM2 Auto-Unlock (LUKS2)

Petunia uses TPM2 to unseal the LUKS2 keyslot at boot without a passphrase, enabling unattended
reboots. The token is stored in the LUKS2 header (keyslot 1); keyslot 0 (passphrase) remains
as fallback.

### Current state

- **PCR binding:** PCR 0 (UEFI firmware measurement). Secure Boot is not active on this board,
  so PCR 7 (Secure Boot state) is static/zeroed and meaningless as a binding.
- **Re-enrollment trigger:** Any UEFI firmware update changes PCR 0. Re-enroll after every
  BIOS update (see below).
- **NixOS modules:** `security.tpm2.*` and `boot.initrd.systemd.tpm2.enable` in
  `modules/hardware/petunia/tpm2.nix`.

### Device path note

`/dev/disk/by-partlabel/DISK_LUKS` does **not** resolve from userspace — disko creates the GPT
label `disk-main-DISK_LUKS`. Always reference the partition directly:

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

Petunia has two physically identical RDNA4 R9700 GPUs. Both are wired into ROCm/HIP by
`modules/hardware/petunia/rdna4.nix`, which holds the full graphics + compute config
(amdgpu KMS, kernel params, ROCm runtime, `/opt/rocm` symlink, LACT, diagnostics).
The HIP/Vulkan build toolchain is not in the system closure; inference projects consume
`github:tenarches/nix-rdna4` devShells (`llama-rocm` / `llama-vulkan`) directly.

Key settings in `rdna4.nix`:
- `ROCR_VISIBLE_DEVICES=0,1`
- `HCC_AMDGPU_TARGET=gfx1201,gfx1201`
- `pcie_bus_config=performance` kernel param (maximises inter-GPU DMA throughput on X570 x8/x8)

### Verify both GPUs visible

```bash
lspci -vv | grep -A5 "VGA\|3D"
rocminfo | grep -A3 "Agent "   # should list two gfx1201 agents
```

---

## Rebuild procedure

Petunia builds itself — push to GitHub first, then run on the host:

```bash
# On your workstation:
git push origin main

# On petunia (in tmux):
time nixos-rebuild switch --flake github:mister2d/nix-nexus#petunia
```

Typical build times: 75s–70s for config-only changes; longer if new packages are fetched.
