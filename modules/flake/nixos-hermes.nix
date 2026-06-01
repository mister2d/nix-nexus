{ inputs, config, ... }:
let
  hm = config.flake.modules.homeManager;
  inherit (config.flake.modules) nixos;
in
{
  flake.nixosConfigurations.hermes = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      inherit (inputs) self;
      nixosModules = nixos;
      homeManagerModules = hm;
    };
    modules = [
      nixos.overlays-global
      nixos.hermes-mcp-overlay
      nixos.hermes-default
      nixos.llm-agents-hermes
      inputs.home-manager.nixosModules.home-manager
      nixos.hm-groot-hermes
    ];
  };
}
