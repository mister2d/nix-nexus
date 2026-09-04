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
