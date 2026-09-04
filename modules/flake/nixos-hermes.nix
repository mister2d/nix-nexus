{ inputs, config, ... }:
let
  homeManagerModules = config.flake.modules.homeManager;
  inherit (config.flake.modules) nixos;
in
{
  flake.nixosConfigurations.hermes = inputs.nixpkgs.lib.nixosSystem {
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
      nixos.hermes-mcp-overlay
      nixos.hermes-default
      nixos.llm-agents-hermes
      inputs.home-manager.nixosModules.home-manager
      nixos.hm-groot-hermes
    ];
  };
}
