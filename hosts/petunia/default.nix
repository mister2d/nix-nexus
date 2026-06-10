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
        nixosModules.desktop-sway

        # CachyOS server kernel (EEVDF + 300Hz + no preemption + x86_64-v3)
        nixosModules.hardware-kernel-cachyos
      ];

      # Machine-specific overrides
      networking.hostName = "petunia";

      # CachyOS server kernel: EEVDF scheduler, 300Hz timer, no preemption, x86_64-v3 ISA.
      # processorOpt requires a local build (~45 min on the 5600X); ZFS wired via zfs-cachyos.
      hardware.cachyosKernel = {
        enable = true;
        variant = "server";
        processorOpt = "x86_64-v3";
        enableZfs = true;
        enableCustomBuild = true;
      };

      # ZFS Workstation Tuning (AI/ML & Coding)
      nix-nexus.zfs = {
        # Assuming 64GB RAM (Swap is 66G).
        # 16GB ARC is a good balance for datasets without starving GPU/Apps.
        arcMax = 17179869184; # 16GB
        arcMin = 4294967296; # 4GB
        arcSysFree = 8589934592; # 8GB (Generous headroom for GPU/drivers/OOM safety)

        # Coding & Small Files optimization
        metaLimitPercent = 80;
        dnodeLimitPercent = 20;
      };

      # Host ID for ZFS (needs to be unique and persistent)
      # Generated randomly for petunia
      networking.hostId = "4e1a0d9b";

      # Enable NVIDIA-specific configurations if needed
      # (Already handled by profile, but can add overrides here)
    };
}
