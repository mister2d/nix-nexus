# nix-skills-mcp: MCP server that serves Nix Agent Skills and checks flakes with the nix_verify tool.
# Registry key: modules.nixos.services-nix-skills-mcp
# Imports the module from the nix-skills-mcp flake input (tag v0.2.0). The module builds the package with the host
# pkgs, so this file does not apply the overlay.
# The server listens on 127.0.0.1:8011 and has no client auth: the Bifrost devenv gateway on this host is its only
# client (nix-bifrost, MCP client nix_skills, Code Mode off). For this reason tokenFile stays null.
# Decisions of 2026-11-10:
# - Deploy as a NixOS service on petunia behind the Bifrost gateway with Code Mode off.
# - readOnlyPaths = []: nix_verify cannot read host directories. It checks only paths that the service can read.
# - The Tasks extension (io.modelcontextprotocol/tasks) needs a Bifrost relay patch in nix-bifrost.
{ inputs, ... }:
{
  modules.nixos.services-nix-skills-mcp = _: {
    imports = [ inputs.nix-skills-mcp.nixosModules.default ];

    services.nix-skills-mcp = {
      enable = true;
      port = 8011;
      readOnlyPaths = [ ];
    };
  };
}
