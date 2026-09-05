# Host: hermes (NixOS x86_64 Proxmox LXC server).
# Registry key: flake.modules.nixos.hermes-mcp-overlay
# Configures: applies the flake.overlays.mcp overlay.
# Imported by: modules/flake/nixos-hermes.nix.
_: {
  flake.modules.nixos.hermes-mcp-overlay =
    { inputs, ... }:
    {
      nixpkgs.overlays = [ inputs.self.overlays.mcp ];
    };
}
