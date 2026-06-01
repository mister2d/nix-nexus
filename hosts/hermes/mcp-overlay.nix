{ inputs, ... }:
{
  nixpkgs.overlays = [ inputs.self.overlays.mcp ];
}
