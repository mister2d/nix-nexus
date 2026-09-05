# Host: sweet16 (NixOS x86_64 workstation).
# Registry key: flake.modules.nixos.hm-ddukes-sweet16
# Composes: core-home-manager, sweet16-home.
_: {
  flake.modules.nixos.hm-ddukes-sweet16 =
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
        homeManagerModules.sweet16-home
      ];
    };
}
