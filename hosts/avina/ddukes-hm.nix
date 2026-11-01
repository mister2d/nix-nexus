# Host: avina (NixOS x86_64 Proxmox LXC server).
# Registry key: modules.nixos.hm-ddukes-avina
# Composes: core-home-manager, avina-home.
_: {
  modules.nixos.hm-ddukes-avina =
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
        homeManagerModules.avina-home
      ];
    };
}
