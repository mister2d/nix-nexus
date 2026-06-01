{ inputs, config, ... }:
let
  hm = config.flake.modules.homeManager;
in
{
  # Usage: 'nix run home-manager/release-25.11 -- switch --flake .#groot@forge'
  flake.homeConfigurations."groot@forge" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
    modules = [
      inputs.nixvim.homeModules.nixvim
      hm.forge-home
    ];
    extraSpecialArgs = {
      inherit (inputs) self;
      inherit inputs;
      homeManagerModules = hm;
    };
  };
}
