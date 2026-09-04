_: {
  flake.modules.nixos.core-home-manager =
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
      };
    };
}
