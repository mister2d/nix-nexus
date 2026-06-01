_: {
  flake.modules.nixos.overlays-global =
    { inputs, ... }:
    {
      nixpkgs.overlays = [ inputs.self.overlays.buildFixes ];
      nixpkgs.config.allowUnfree = true;
    };
}
