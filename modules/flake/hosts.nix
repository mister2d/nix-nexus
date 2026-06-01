{
  inputs,
  config,
  ...
}:
let
  inherit (inputs) home-manager nixvim;
  hm = config.flake.modules.homeManager;
in
{
  flake = {
    homeConfigurations = {
      # Hostname: forge (Debian 12)
      # Usage: 'nix run home-manager/release-25.11 -- switch --flake .#groot@forge'
      "groot@forge" = home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
        modules = [
          nixvim.homeModules.nixvim
          hm.forge-home
        ];
        extraSpecialArgs = {
          inherit (inputs) self;
          inherit inputs;
          homeManagerModules = hm;
        };
      };
    };

  };
}
