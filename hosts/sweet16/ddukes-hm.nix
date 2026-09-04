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
