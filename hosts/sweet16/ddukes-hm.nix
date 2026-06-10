_: {
  flake.modules.nixos.hm-ddukes-sweet16 =
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
          homeManagerModules.sweet16-home
        ];
      };
    };
}
