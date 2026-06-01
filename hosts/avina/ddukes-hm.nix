{ inputs, homeManagerModules, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
    extraSpecialArgs = {
      inherit (inputs) self;
      inherit inputs homeManagerModules;
    };
    users.ddukes.imports = [
      inputs.nixvim.homeModules.nixvim
      homeManagerModules.avina-home
    ];
  };
}
