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
      # Hostname: dualie (Debian Trixie)
      # Usage: 'nix run home-manager/master -- switch --flake .#groot@dualie'
      "groot@dualie" = home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
        modules = [
          nixvim.homeModules.nixvim
          hm.dualie-home
        ];
        extraSpecialArgs = {
          inherit (inputs) self;
          inherit inputs;
          homeManagerModules = hm;
        };
      };

      # Hostname: rk3588 (ARM64 SBC Fleet)
      # Usage: 'nix run home-manager/release-25.11 -- switch --flake .#groot@rk3588'
      "groot@rk3588" = home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages."aarch64-linux";
        modules = [
          nixvim.homeModules.nixvim
          hm.rk3588-home
        ];
        extraSpecialArgs = {
          inherit (inputs) self;
          inherit inputs;
          homeManagerModules = hm;
        };
      };

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
