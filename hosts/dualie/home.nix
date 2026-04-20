{
  pkgs,
  inputs,
  ...
}:

let
  unstable-pkgs = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  imports = [
    ../../modules/user/bash.nix
    ../../modules/user/neovim-home.nix
    ../../modules/user/terminal-home.nix
    ../../modules/user/dev-home.nix
  ];

  # Home Configuration
  home = {
    username = "groot";
    homeDirectory = "/mnt/ironhide/home/groot";
    stateVersion = "25.11"; # Matching codebase standard for 2026

    # Basic packages derived from debug/dualie_home_profile.nix
    # Other tools (git, htop, etc.) are already included in the imported modules.
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
  programs.dev-home = {
    enable = true;
    enableMcpServers = false;
    enableLlmAgents = false;
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Allow unfree packages for the Home Manager profile
  nixpkgs.config.allowUnfree = true;

  # Add Model Control Protocol (MCP) server packages via overlay
  # This matches the system-wide configuration on sweet16.
  nixpkgs.overlays = [ inputs.mcp-servers-nix.overlays.default ];
}
