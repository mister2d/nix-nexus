# Host: dualie (Debian x86_64, standalone Home Manager).
# Registry key: flake.modules.homeManager.dualie-home
# Composes: user-standalone-home.
_: {
  flake.modules.homeManager.dualie-home =
    {
      pkgs,
      inputs,
      homeManagerModules,
      ...
    }:

    let
      pin = import ../../lib/pinned-pkgs.nix { inherit pkgs; };

      unstable-pkgs = pin.pinned inputs.nixpkgs-unstable;
    in
    {
      imports = [ homeManagerModules.user-standalone-home ];

      # Home Configuration
      home = {
        username = "groot";
        homeDirectory = "/mnt/ironhide/home/groot";
        stateVersion = "25.11"; # Matching codebase standard for 2026

        # Other tools (git, htop, etc.) are included via imported modules.
        packages = with pkgs; [
          zstd
          curl
          wget
          unstable-pkgs.llama-swap
        ];
      };

      # Development Home Profile
      # Disabled MCP servers and LLM agents because they require modern CPU instructions (e.g. AVX2)
      # that are missing on Ivy Bridge Xeons.
      nix-nexus.user.dev = {
        enable = true;
        enableMcpServers = false;
        enableLlmAgents = false;
      };

      # Add Model Control Protocol (MCP) server packages via overlay
      # This matches the system-wide configuration on sweet16.
      nixpkgs.overlays = [ inputs.mcp-servers-nix.overlays.default ];
    };
}
