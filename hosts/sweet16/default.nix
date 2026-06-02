_: {
  flake.modules.nixos.sweet16-default =
    {
      pkgs,
      inputs,
      nixosModules,
      ...
    }:

    {
      imports = [
        # Include the results of the hardware scan (generated at install time)
        nixosModules.sweet16-hardware

        # Machine-specific profiles (Quirks & Hardware)
        nixosModules.hardware-z16

        # CachyOS Optimized Kernel
        nixosModules.hardware-kernel-cachyos

        # Core System Profile (Every machine gets this)
        nixosModules.workstation-default

        # Ceph Integration
        nixosModules.core-ceph

        # Printing Support
        nixosModules.core-printing

        # Functional Profiles (Suites)
        nixosModules.desktop-default
        nixosModules.development-default

        # Compositors & Desktop Environments
        nixosModules.desktop-sway
      ];

      # Machine-specific overrides
      networking.hostName = "sweet16";

      # Limit parallel build jobs to avoid memory exhaustion (16-thread, 32GB RAM).
      # Each heavy job (LLVM, Chromium) can consume 2-4GB. Caps at ps3 to keep
      # ZFS ARC responsive during builds.
      nix.settings = {
        max-jobs = 8;
        cores = 2;
      };

      # Tailscale roaming: accept-routes is suppressed on home SSIDs (LAN is directly
      # reachable) and enabled everywhere else (road/hotspot access to LAN resources).
      nix-nexus.networking.tailscale.homeSSIDs = [
        "Trial"
      ];

      # Prevent NVMe from entering ps 4 (9500µs exit latency); caps at ps 3 (1200µs) for ZFS
      boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=9000" ];

      # CachyOS Kernel Configuration
      hardware.cachyosKernel = {
        enable = true;
        processorOpt = "x86_64-v3"; # Ryzen 6000 "Rembrandt" (Zen 3+)
        enableZfs = true;
        enableBbr3 = true;
        enableAcpiCall = true;
        hugepageMode = "madvise";
      };

      # ZFS Performance Profile (Coding & General Purpose)
      nix-nexus.zfs = {
        # Assuming 32GB RAM.
        # 8GB ARC is a good balance for a mobile workstation.
        arcMax = 8589934592; # 8GB
        arcMin = 2147483648; # 2GB
        arcSysFree = 4294967296; # 4GB (Safety margin for Nix builds)

        # Coding & Development Optimization
        metaLimitPercent = 85;
        dnodeLimitPercent = 25;
      };

      environment.systemPackages =
        let
          # Use pinned Ceph input for consistency
          ceph-pkgs = import inputs.pkgs-ceph {
            inherit (pkgs.stdenv.hostPlatform) system;
            config.allowUnfree = true;
          };
        in
        with pkgs;
        [
          # Ceph Integration:
          # - ceph: Provides 'ceph-fuse' for user-space mounts
          # - ceph-client: Provides 'ceph', 'rados', 'rbd' and other essential tools
          ceph-pkgs.ceph
          ceph-pkgs.ceph-client
        ];

      # Host ID for ZFS (needs to be unique and persistent)
      networking.hostId = "efca0213";
    };
}
