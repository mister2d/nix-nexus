# hybrid-web-search-mcp: MCP server with web search, fetch and crawl tools (SearXNG, Crawl4AI REST).
# Registry key: modules.nixos.services-hybrid-web-search-mcp
# Imports the module from the hybrid-web-search-mcp flake input. The module builds the package with the host pkgs.
# The server listens on 127.0.0.1:8010 and has no client auth: the Bifrost devenv gateway on this host is its only
# client (nix-bifrost, MCP client hybrid_web_search, Code Mode off).
# The Crawl4AI and SearXNG URLs and the Crawl4AI token are the module defaults. To set a non-default token, give
# crawl4aiTokenFile a sops secret path: the unit reads it through LoadCredential, so it stays out of the store.
{ inputs, ... }:
{
  modules.nixos.services-hybrid-web-search-mcp = _: {
    imports = [ inputs.hybrid-web-search-mcp.nixosModules.default ];

    services.hybrid-web-search-mcp.enable = true;
  };
}
