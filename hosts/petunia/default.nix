_: {
  flake.modules.nixos.petunia-default =
    { nixosModules, ... }:

    {
      imports = [
        # Declarative Disk Partitioning (LUKS + ZFS)
        nixosModules.petunia-disko

        # Include the results of the hardware scan (generated at install time)
        nixosModules.petunia-hardware

        # Machine-specific profiles (Quirks & Hardware)
        nixosModules.hardware-petunia

        # TPM2 for LUKS auto-unlock. Enrolled against PCR 0 only (Secure Boot
        # inactive, so PCR 7 is meaningless). Accepted risk on a
        # physically-controlled desktop — see docs/secrets.md.
        nixosModules.core-tpm2

        # Core System Profile (Every machine gets this)
        nixosModules.workstation-default

        # Ceph Integration
        nixosModules.core-ceph

        # Printing Support
        nixosModules.core-printing

        # Functional Profiles (Suites)
        nixosModules.desktop-default
        nixosModules.development-default

        # Compositor
        nixosModules.desktop-hyprland

        # CachyOS server kernel (EEVDF + 300Hz + no preemption + x86_64-v3)
        nixosModules.hardware-kernel-cachyos

        # Unprivileged OpenRGB SDK server
        nixosModules.services-openrgb
      ];

      # Machine-specific overrides
      networking.hostName = "petunia";

      # Grants ddukes direct OpenRGB device access (group-scoped udev rules
      # from services-openrgb); list-merges with core-users.
      users.users.ddukes.extraGroups = [ "openrgb" ];

      # CachyOS server kernel: EEVDF scheduler, 300Hz timer, no preemption, x86_64-v3 ISA.
      # processorOpt requires a local build (~45 min on the 5600X); ZFS wired via zfs-cachyos.
      hardware.cachyosKernel = {
        enable = true;
        variant = "server";
        processorOpt = "x86_64-v3";
        enableZfs = true;
        enableCustomBuild = true;
      };

      # ZFS Inference Tuning
      nix-nexus.zfs = {
        # 64GB RAM; ARC kept small to maximise KV-cache / CPU-offload headroom.
        # NVMe latency (~50-100µs) makes a large ARC unnecessary.
        arcMax = 4294967296; # 4GB
        arcMin = 1073741824; # 1GB
        arcSysFree = 8589934592; # 8GB (ROCm dual-GPU dynamic alloc headroom)

        # Inference is data-heavy, not metadata-heavy; favour data cache.
        metaLimitPercent = 50;
        dnodeLimitPercent = 10;
      };

      # Host ID for ZFS (needs to be unique and persistent)
      # Generated randomly for petunia
      networking.hostId = "4e1a0d9b";

      swapDevices = [
        {
          device = "/dev/disk/by-partuuid/5eacdc8e-39ba-435a-8283-bb0e290e7846";
          randomEncryption = {
            enable = true;
            allowDiscards = true;
          };
        }
      ];
    };
}
