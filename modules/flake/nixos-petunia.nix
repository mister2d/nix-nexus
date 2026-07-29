{ inputs, config, ... }:
let
  hm = config.flake.modules.homeManager;
  inherit (config.flake.modules) nixos;
in
{
  flake.nixosConfigurations.petunia = inputs.nixpkgs-unstable.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      inherit (inputs) self;
      nixosModules = nixos;
      homeManagerModules = hm;
    };
    modules = [
      nixos.overlays-global
      inputs.sops-nix.nixosModules.sops
      inputs.disko.nixosModules.disko
      inputs.nixos-hardware.nixosModules.common-cpu-amd
      inputs.nixos-hardware.nixosModules.common-gpu-amd
      inputs.nixos-hardware.nixosModules.common-pc-ssd
      nixos.petunia-default
      inputs.home-manager-unstable.nixosModules.home-manager
      nixos.hm-ddukes-petunia
    ];
  };
}
