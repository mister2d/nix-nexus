_: {
  flake.modules.nixos.hm-ddukes-petunia =
    { inputs, homeManagerModules, ... }:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak-$(date +%Y%m%d%H%M%S)";
        extraSpecialArgs = {
          inherit (inputs) self;
          inherit inputs homeManagerModules;
        };
        users.ddukes.imports = [
          inputs.nixvim.homeModules.nixvim
          homeManagerModules.petunia-home
        ];
      };
    };
}
