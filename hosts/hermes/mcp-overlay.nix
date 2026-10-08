# Host: hermes (NixOS x86_64 Proxmox LXC server).
# Registry key: flake.modules.nixos.hermes-mcp-overlay
# Configures: applies the nix-devshell default overlay (context-mode).
# Imported by: modules/flake/nixos-hermes.nix.
{ inputs, ... }:
{
  flake.modules.nixos.hermes-mcp-overlay = _: {
    nixpkgs.overlays = [ inputs.nix-devshell.overlays.default ];
  };
}
