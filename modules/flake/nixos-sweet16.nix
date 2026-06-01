{ inputs, config, ... }:
let
  hm = config.flake.modules.homeManager;
  inherit (config.flake.modules) nixos;
in
{
  flake.nixosConfigurations.sweet16 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      inherit (inputs) self;
      nixosModules = nixos;
      homeManagerModules = hm;
    };
    modules = [
      nixos.overlays-global
      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z
      inputs.nixos-hardware.nixosModules.common-cpu-amd
      inputs.nixos-hardware.nixosModules.common-gpu-amd
      inputs.nixos-hardware.nixosModules.common-pc-ssd
      nixos.sweet16-default
      inputs.home-manager.nixosModules.home-manager
      nixos.hm-ddukes-sweet16
    ];
  };
}
