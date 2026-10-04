# Host: hermes (NixOS x86_64 Proxmox LXC server).
# Registry key: flake.modules.nixos.llm-agents-hermes
# Configures: applies the nix-devshell hermes-agent overlay (vendored hermes-agent plus context-mode-hermes).
# Imported by: modules/flake/nixos-hermes.nix.
{ inputs, ... }:
{
  flake.modules.nixos.llm-agents-hermes = {
    imports = [ inputs.nix-devshell.nixosModules.dev-hermes-agent ];
  };
}
