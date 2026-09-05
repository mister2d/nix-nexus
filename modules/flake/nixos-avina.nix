# Flake assembly for avina. Sets flake.nixosConfigurations.avina.
# Composes overlays-global, sops, avina-default, matrix-pin-stable, home-manager, hm-ddukes-avina.
{ inputs, config, ... }:
let
  homeManagerModules = config.flake.modules.homeManager;
  inherit (config.flake.modules) nixos;
in
{
  flake.nixosConfigurations.avina = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      inherit (inputs) self;
      nixosModules = nixos;
      inherit homeManagerModules;
    };
    modules = [
      nixos.overlays-global
      inputs.sops-nix.nixosModules.sops
      nixos.avina-default
      nixos.matrix-pin-stable
      inputs.home-manager.nixosModules.home-manager
      nixos.hm-ddukes-avina
    ];
  };
}
