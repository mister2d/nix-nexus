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
wires both cards into ROCm/HIP through the `nix-rdna4` flake input. The file imports the
`rdna4-full` and `rdna4-dual` NixOS modules and applies the `rocm-sysroot` overlay. Those
modules provide amdgpu KMS, kernel params, the ROCm runtime, the `/opt/rocm` symlink, LACT,
udev rules, and diagnostics. The HIP/Vulkan build toolchain stays out of the system closure
(`rdna4.buildEnv.enable` stays off). Inference projects pull `github:tenarches/nix-rdna4`
devShells (`llama-rocm` and `llama-vulkan`) directly instead.

Key settings in `rdna4.nix`:
- `rdna4.dualGpu.enable = true`: `ROCR_VISIBLE_DEVICES=0,1`, `HCC_AMDGPU_TARGET=gfx1201`, and
  the `pcie_bus_config=performance` kernel param. The param raises inter-GPU DMA throughput on
  the X570 x8/x8 link.
- `rdna4.limits.enable = true`: memlock unlimited and nofile 65536 for the `render` and `video`
  groups, and `vm.max_map_count=1048576`. PAM limits apply to login sessions only; a systemd
  service needs `LimitMEMLOCK` and `LimitNOFILE` in its own unit.

### Verify both GPUs visible

```bash
lspci -vv | grep -A5 "VGA\|3D"
rocminfo | grep -A3 "Agent "   # should list two gfx1201 agents
```

### GPU power profile

`modules/hardware/petunia/gpu-power.nix` declares the LACT default profile through
`services.lact.settings`: both R9700 cards run a 230 W cap with no voltage offset. A -75 mV
offset was dropped: the driver rejects overdrive table uploads on this kernel, so the offset
could not be applied or verified reliably. A udev rule keeps both cards out of runtime
suspend (`power/control=on`), because a suspended card answers `EBUSY` on its power sysfs
files. `lactd` re-applies the profile on every start and GPU reload. The card limits are
210 W minimum,
300 W stock, 330 W maximum, with a -200 mV to 0 mV offset range.

`gpu-profile` switches profiles (source: `lib/petunia/gpu-profile.sh`):

```bash
gpu-profile status                          # cap, limits, offset, performance level, lactd state
gpu-profile default                         # declared profile (230 W, no offset), lactd running
gpu-profile stock                           # 300 W, no offset, lactd stopped
gpu-profile custom --cap 250 --offset -60   # guarded values, lactd stopped
```

`stock` and `custom` stop `lactd` and write sysfs directly, because the LACT CLI cannot set a
voltage offset and the NixOS-rendered config is read-only. They last until
`gpu-profile default` or a reboot. A reboot returns to the declared profile.

`custom` refuses values outside these limits:
- The cap must sit inside the driver range. A cap above stock needs `--over-stock`.
- Positive offsets are refused, and so are offsets outside the card range.
- An offset below -100 mV needs `--force`. Below -80 mV it warns.
- An offset below -50 mV needs a cap under stock. Community reports of instability come from
  undervolting with uncapped boost.

Long-duration R9700 data does not exist, so run a sustained load test before you treat
any offset as safe for 24/7 use.

---

## Model storage and swap

Models and the Hugging Face hub cache live on dedicated XFS partitions, mounted by partition
UUID in `modules/hardware/petunia/model-storage.nix`:

| Mount | Device | Notes |
|---|---|---|
| `/data/huggingface/models` | Phison E12 (`nvme2n1p1`), whole drive, 477 GiB | The n-gram table is mmap'd from here, so a page fault reads 4 KiB instead of a 1 MiB ZFS record. |
| `/data/huggingface/hub` | Micron 2400 (`nvme1n1p3`), 633 GiB | Source checkpoints. The NTFS "Data" partition (`nvme1n1p1`) was shrunk to 950 GiB to make room. |

Both mounts use `noatime,nofail,x-systemd.device-timeout=10s`, and `services.fstrim` is on.
The pool (`petunia/data`) keeps both directories as empty mount points. The prefix-cache
kvcache stays under `/data/llm-cache` on the encrypted pool because it holds conversation
content.

Swap is zram first (zstd, 25% of RAM, priority 100) from the shared `core-zram-swap` module,
with the 66 GiB random-key LUKS swap on the Micron (`nvme1n1p2`) as overflow at priority 10.
`vm.swappiness` is 100 and `vm.page-cluster` is 0, the same as sweet16.

A one-time live migration (NTFS shrink, new partitions, checksum-verified copies) moved the
data; the script is not kept in the repo (see git history of `hosts/petunia/migrate-storage.sh`).
The Windows profile backup lives in the ZFS dataset `petunia/backup` at `/backup/windows-profile`.
OneDrive files in it are zero-filled placeholders; the real files exist only in the cloud.

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
