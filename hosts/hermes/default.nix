# Host: hermes (NixOS x86_64 Proxmox LXC server).
# Registry key: flake.modules.nixos.hermes-default
# Composes: hardware-proxmox-lxc, server-default, core-groot.
_: {
  flake.modules.nixos.hermes-default =
    {
      pkgs,
      inputs,
      nixosModules,
      ...
    }:
    let
      pin = import ../../lib/pinned-pkgs.nix { inherit pkgs; };

      unstablePkgs = pin.pinned inputs.nixpkgs-unstable;
    in
    {
      imports = [
        nixosModules.hardware-proxmox-lxc
        nixosModules.server-default
        nixosModules.core-groot
      ];

      proxmoxLXC.privileged = true;

      security.sudo.enable = false;

      programs = {
        nix-ld.enable = true;

        singularity = {
          enable = true;
          package = unstablePkgs.apptainer;
          systemBinPaths = [ "/run/current-system/sw/bin" ];
        };
      };
    };
}
