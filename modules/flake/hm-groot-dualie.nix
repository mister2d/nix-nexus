{ inputs, config, ... }:
let
  hm = config.flake.modules.homeManager;
in
{
  # Usage: 'nix run home-manager/master -- switch --flake .#groot@dualie'
  flake.homeConfigurations."groot@dualie" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
    modules = [
      inputs.nixvim.homeModules.nixvim
      hm.dualie-home
    ];
    extraSpecialArgs = {
      inherit (inputs) self;
      inherit inputs;
      homeManagerModules = hm;
    };
  };
}
