{
  pkgs,
  inputs,
  ...
}:

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
    homeDirectory = "/home/groot";
    stateVersion = "25.11"; # Matching codebase standard for 2026

    # Add $HOME/bin to user's PATH
    sessionPath = [
      "$HOME/bin"
    ];

    # Basic packages derived from debug/dualie_home_profile.nix
    # Other tools (git, htop, etc.) are already included in the imported modules.
    packages = with pkgs; [
      zstd
      curl
      wget
    ];
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Allow unfree packages for the Home Manager profile
  nixpkgs.config.allowUnfree = true;

  # Add Model Control Protocol (MCP) server packages via overlay
  # This matches the system-wide configuration on sweet16.
  nixpkgs.overlays = [ inputs.mcp-servers-nix.overlays.default ];
}
