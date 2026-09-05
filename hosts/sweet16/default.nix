# Host: sweet16 (NixOS x86_64 workstation).
# Registry key: flake.modules.nixos.sweet16-default
# Composes: sweet16-hardware, hardware-z16, core-tpm2, core-microvm-host, hardware-kernel-cachyos, workstation-default, core-ceph, core-printing, desktop-default, development-default, desktop-hyprland.
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

        # sweet16 runs the permafrost microvm guests. The bridge, NAT and
        # kvm policy come from core-microvm-host.
        nixosModules.core-microvm-host

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

        # Tailscale roaming: accept-routes is suppressed on home SSIDs, since
        # the LAN is directly reachable there. It stays enabled everywhere
        # else, for road and hotspot access to LAN resources.
        networking.tailscale.homeSSIDs = [
          "Trial"
        ];

        # Userspace TPM access for ssh-tpm-agent and tpm2-pkcs11.
        tpm2.users = [ "ddukes" ];

        # Host side of the permafrost microvm sandbox.
        virtualization.microvm.enable = true;
      };

      # Prevent NVMe from entering ps 4 (9500µs exit latency). Caps at ps 3 (1200µs) for ZFS.
      boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=9000" ];

      # CachyOS Kernel Configuration
      nix-nexus.kernel.cachyos = {
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
