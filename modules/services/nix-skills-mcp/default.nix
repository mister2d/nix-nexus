# nix-skills-mcp: MCP server that serves Nix Agent Skills and checks flakes with the nix_verify tool.
# Registry key: modules.nixos.services-nix-skills-mcp
# Imports the module from the nix-skills-mcp flake input (tag v0.2.0). The module builds the package with the host
# pkgs, so this file does not apply the overlay.
# The server listens on 127.0.0.1:8011 and has no client auth: the Bifrost devenv gateway on this host is its only
# client (nix-bifrost, MCP client nix_skills, Code Mode off). For this reason tokenFile stays null.
# Decisions of 2026-11-10:
# - Deploy as a NixOS service on petunia behind the Bifrost gateway with Code Mode off.
# - readOnlyPaths = []: nix_verify cannot read host directories (replaced on 2026-11-13, below).
# - The Tasks extension (io.modelcontextprotocol/tasks) needs a Bifrost relay patch in nix-bifrost.
# Change of 2026-11-13 (pi-durable#133): nix_verify reads the workspaces of the factory slots, and nothing else on
# the host. The host half of the share comes from nix-permafrost (host-workspaces): the slot directories in
# /var/lib/permafrost-workspaces, and one read-only, nosymfollow mount for each slot below
# /srv/permafrost-workspaces. The service reads only that view, as a member of the reader group, and every start
# runs the mount check first. pi-durable rewrites a guest path to the view (slots.verify.readerRoot).
{ inputs, ... }:
let
  # The module is a flake-parts module of the guest repository; it reads only lib.
  hostWorkspaces =
    lib:
    (import "${inputs.nix-permafrost}/modules/host/workspaces.nix" { inherit lib; })
    .flake.modules.nixos.host-workspaces;
in
{
  modules.nixos.services-nix-skills-mcp =
    { config, lib, ... }:
    let
      ws = config.permafrost.host.workspaces;
    in
    {
      imports = [
        inputs.nix-skills-mcp.nixosModules.default
        (hostWorkspaces lib)
      ];

      services.nix-skills-mcp = {
        enable = true;
        port = 8011;
        readOnlyPaths = [ ws.readerPath ];
      };

      systemd.services.nix-skills-mcp = {
        # The check fails when a slot mount is missing or lost ro, nosymfollow
        # or nosuid. Requires= and After= make each start of the reader run it.
        requires = [ "permafrost-workspaces-ro-check.service" ];
        after = [ "permafrost-workspaces-ro-check.service" ];
        serviceConfig = {
          SupplementaryGroups = [ ws.readerGroup ];
          # The writable tree itself stays out of reach; only the view is read.
          InaccessiblePaths = [ ws.path ];
        };
      };
    };
}
