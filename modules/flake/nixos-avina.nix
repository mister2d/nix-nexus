{ inputs, config, ... }:
let
  hm = config.flake.modules.homeManager;
  inherit (config.flake.modules) nixos;
in
{
  flake.nixosConfigurations.avina = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      inherit (inputs) self;
      nixosModules = nixos;
      homeManagerModules = hm;
    };
    modules = [
      nixos.overlays-global
      nixos.avina-default
      nixos.matrix-pin-stable
      inputs.home-manager.nixosModules.home-manager
      nixos.hm-ddukes-avina
    ];
  };
}
