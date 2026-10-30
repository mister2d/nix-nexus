# Host: petunia (NixOS x86_64 workstation).
# Registry key: flake.modules.nixos.petunia-default
# Composes: petunia-disko, petunia-hardware, hardware-petunia, core-tpm2, core-microvm-host, workstation-default, core-ceph, core-printing, desktop-default, development-default, desktop-hyprland, hardware-kernel-cachyos, services-openrgb, core-zram-swap, core-agent-identities, core-credstore, core-agent-ssh-target, services-pi-durable, services-bifrost-front-door.
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

        # petunia runs permafrost microvm guests. The bridge, NAT and kvm
        # policy come from core-microvm-host.
        nixosModules.core-microvm-host

        # Fixed-uid agent identities (pdh-pi, agent) with no TPM access
        nixosModules.core-agent-identities

        # TPM2-sealed credential directory and delivery self-test
        nixosModules.core-credstore

        # Certificate-only restricted SSH login for the agent identity
        nixosModules.core-agent-ssh-target

        # pi-durable harness instance (execution guest started by hand)
        nixosModules.services-pi-durable
        # Bifrost HTTPS front door on :8443
        nixosModules.services-bifrost-front-door

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

        # Compressed RAM swap ahead of the disk swap device
        nixosModules.core-zram-swap
      ];

      zramSwap.memoryPercent = 25;

      # Machine-specific overrides

      # Grants ddukes direct OpenRGB device access (group-scoped udev rules
      # from services-openrgb). List-merges with core-users.
      users.users.ddukes.extraGroups = [ "openrgb" ];

      nix-nexus = {
        nix.signing.enable = true;

        # CachyOS server kernel: EEVDF scheduler, 300Hz timer, no preemption, x86_64-v3 ISA.
        # processorOpt requires a local build (~45 min on the 5600X). ZFS wires in via zfs-cachyos.
        kernel.cachyos = {
          enable = true;
          variant = "server";
          processorOpt = "x86_64-v3";
          enableZfs = true;
          enableCustomBuild = true;
        };

        # Userspace TPM access for ssh-tpm-agent and tpm2-pkcs11.
        tpm2.users = [ "ddukes" ];

        # Host side of the permafrost microvm sandbox.
        virtualization.microvm.enable = true;
      };

      networking = {
        hostName = "petunia";
        # The pi-durable front door certificate is issued for the fqdn, and the
        # PKI role only issues for .home.lan names.
        domain = "home.lan";
        # Host ID for ZFS (needs to be unique and persistent)
        # Generated randomly for petunia
        hostId = "4e1a0d9b";
      };

      swapDevices = [
        {
          device = "/dev/disk/by-partuuid/5eacdc8e-39ba-435a-8283-bb0e290e7846";
          priority = 10;
          randomEncryption = {
            enable = true;
            allowDiscards = true;
          };
        }
      ];
    };
}
