{
  inputs,
  config,
  lib,
  ...
}:
let
  hm = config.flake.modules.homeManager;
  hosts = {
    dualie = "x86_64-linux";
    forge = "x86_64-linux";
    rk3588 = "aarch64-linux";
  };
in
{
  # Usage: 'nix run home-manager/master -- switch --flake .#groot@dualie'
  # Usage: 'nix run home-manager/release-25.11 -- switch --flake .#groot@forge'
  # Usage: 'nix run home-manager/release-25.11 -- switch --flake .#groot@rk3588'
  flake.homeConfigurations = lib.mapAttrs' (
    host: system:
    lib.nameValuePair "groot@${host}" (
      inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        modules = [
          inputs.nixvim.homeModules.nixvim
          hm."${host}-home"
        ];
        extraSpecialArgs = {
          inherit (inputs) self;
          inherit inputs;
          homeManagerModules = hm;
        };
      }
    )
  ) hosts;
}
