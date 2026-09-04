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

        # TPM2 for LUKS unlock. This is a laptop: enrollment MUST carry
        # --tpm2-with-pin=yes. Plain auto-unseal means power-on equals unlocked
        # disk, including the sops age key. See docs/secrets.md.
        nixosModules.core-tpm2

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

        # Compositor & Shell
        nixosModules.desktop-hyprland
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

      nix-nexus = {
        # Desktop theme, from the lib/themes registry.
        theme.name = "catppuccin-mocha";

        # Tailscale roaming: accept-routes is suppressed on home SSIDs (LAN is directly
        # reachable) and enabled everywhere else (road/hotspot access to LAN resources).
        networking.tailscale.homeSSIDs = [
          "Trial"
        ];

        # Userspace TPM access for ssh-tpm-agent and tpm2-pkcs11.
        tpm2.users = [ "ddukes" ];
      };

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

      environment.systemPackages =
        let
          pin = import ../../lib/pinned-pkgs.nix { inherit pkgs; };

          # Use pinned Ceph input for consistency
          ceph-pkgs = pin.pinned inputs.pkgs-ceph;
        in
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
