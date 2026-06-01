{ inputs, config, ... }:
let
  hm = config.flake.modules.homeManager;
in
{
  # Usage: 'nix run home-manager/release-25.11 -- switch --flake .#groot@rk3588'
  flake.homeConfigurations."groot@rk3588" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages."aarch64-linux";
    modules = [
      inputs.nixvim.homeModules.nixvim
      hm.rk3588-home
    ];
    extraSpecialArgs = {
      inherit (inputs) self;
      inherit inputs;
      homeManagerModules = hm;
    };
  };
}
