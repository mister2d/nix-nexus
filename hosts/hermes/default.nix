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
