# Flake assembly for sweet16. Sets flake.nixosConfigurations.sweet16.
# Composes overlays-global, sops, nixos-hardware Z16/AMD/SSD modules, sweet16-default, home-manager, stylix, hm-ddukes-sweet16.
{ inputs, config, ... }:
let
  homeManagerModules = config.flake.modules.homeManager;
  inherit (config.flake.modules) nixos;
in
{
  flake.nixosConfigurations.sweet16 = inputs.nixpkgs.lib.nixosSystem {
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
      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z
      inputs.nixos-hardware.nixosModules.common-cpu-amd
      inputs.nixos-hardware.nixosModules.common-gpu-amd
      inputs.nixos-hardware.nixosModules.common-pc-ssd
      nixos.sweet16-default
      inputs.home-manager.nixosModules.home-manager
      inputs.stylix.nixosModules.stylix
      nixos.hm-ddukes-sweet16
    ];
  };
}
