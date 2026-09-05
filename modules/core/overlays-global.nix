# Registry key: flake.modules.nixos.overlays-global
# Configures: the buildFixes overlay and nixpkgs.config.allowUnfree for every host.
# Imported by: modules/flake/nixos-sweet16.nix, modules/flake/nixos-petunia.nix, modules/flake/nixos-avina.nix, modules/flake/nixos-hermes.nix.
_: {
  flake.modules.nixos.overlays-global =
    { inputs, ... }:
    {
      nixpkgs.overlays = [ inputs.self.overlays.buildFixes ];
      nixpkgs.config.allowUnfree = true;
    };
}
