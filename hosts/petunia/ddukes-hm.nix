# Host: petunia (NixOS x86_64 workstation).
# Registry key: flake.modules.nixos.hm-ddukes-petunia
# Composes: core-home-manager, petunia-home.
_: {
  flake.modules.nixos.hm-ddukes-petunia =
    {
      inputs,
      homeManagerModules,
      nixosModules,
      ...
    }:
    {
      imports = [ nixosModules.core-home-manager ];
      home-manager.users.ddukes.imports = [
        inputs.nixvim.homeModules.nixvim
        homeManagerModules.petunia-home
      ];
    };
}
