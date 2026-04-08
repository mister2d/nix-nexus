{
  den,
  inputs,
  lib,
  ...
}:
{
  # ============================================================================
  # Federated Fleet Registry
  # ============================================================================

  den = {
    hosts.x86_64-linux = {
      sweet16 = {
        users.ddukes = {
          classes = [ "homeManager" "user" ];
          includes = [ den.aspects.user-ddukes-aspect ];
        };
      };
      petunia = {
        users.ddukes = {
          classes = [ "homeManager" "user" ];
          includes = [ den.aspects.user-ddukes-aspect ];
        };
      };
      avina = {
        users.ddukes = {
          classes = [ "homeManager" "user" ];
          includes = [ den.aspects.user-ddukes-aspect ];
        };
      };
    };

    aspects = {
      # ── Workstations ────────────────────────────────────────────────────────
      sweet16 = {
        includes = [
          den.provides.hostname
          den.aspects.base-aspect
          den.aspects.boot-aspect
          den.aspects.hw-z16-aspect
          den.aspects.zfs-aspect
          den.aspects.networking-aspect
          den.aspects.security-aspect
          den.aspects.sway-aspect
          den.aspects.niri-aspect
          den.aspects.dms-aspect
          den.aspects.desktop-base-aspect
          den.aspects.ceph-aspect
          den.aspects.printing-aspect
        ];
        nixos = { pkgs, ... }: {
          networking.hostId = "efca0213";
          imports = [ ./_hw/sweet16/hardware-configuration.nix ];
          # Narrative: sweet16 defines its own identity while borrowing heavily from shared workstation aspects.
        };
      };

      # ── Compute Nodes ───────────────────────────────────────────────────────
      petunia = {
        users.ddukes = {
          classes = [ "homeManager" "user" ];
          includes = [ den.aspects.user-ddukes-aspect ];
        };
        includes = [
          den.provides.hostname
          den.aspects.base-aspect
          den.aspects.boot-aspect
          den.aspects.hw-petunia-aspect
          den.aspects.zfs-aspect
          den.aspects.networking-aspect
          den.aspects.security-aspect
          den.aspects.sway-aspect
        ];
        nixos = { pkgs, ... }: {
          networking.hostId = "4e1a0d9b";
          imports = [
            inputs.disko.nixosModules.disko
            ./_hw/petunia/hardware-configuration.nix
            ./_hw/petunia/disko.nix
          ];
        };
      };

      # ── Public Infrastructure ───────────────────────────────────────────────
      avina = {
        users.ddukes = {
          classes = [ "homeManager" "user" ];
          includes = [ den.aspects.user-ddukes-aspect ];
        };
        includes = [
          den.provides.hostname
          den.aspects.base-aspect
          den.aspects.security-aspect
          den.aspects.matrix-aspect
          den.aspects.virtualization-aspect
        ];
        nixos = { ... }: {
          nixpkgs.hostPlatform = "x86_64-linux"; # Explicitly set for LXC
          imports = [ "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-lxc.nix" ];
          proxmoxLXC.privileged = false;
          # Narrative: avina is a sovereign node optimized for public Matrix services, intentionally isolated from the Tailscale mesh.
        };
      };
    };
  };
}
