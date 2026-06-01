_: {
  flake.modules.nixos.hermes-mcp-overlay =
    { inputs, ... }:
    {
      nixpkgs.overlays = [ inputs.self.overlays.mcp ];
    };
}
