{
  pkgs,
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
    # Standard Armbian home path for SBC fleet
    homeDirectory = "/home/groot";
    stateVersion = "25.11"; # Matching codebase standard for 2026

    # Add $HOME/bin to user's PATH
    sessionPath = [
      "$HOME/bin"
    ];

    # Basic packages derived from debug/rk3588.md
    # Other tools (git, htop, etc.) are already included in the imported modules.
    packages = with pkgs; [
      zstd
      curl
      wget
      htop
      tmux
    ];
  };

  # Development Home Profile
  # Disabled AI/Compute modules for ARM64 SBC RAM/CPU constraints.
  # These often require modern x86_64 CPU instructions or heavy resources.
  programs.dev-home = {
    enable = true;
    enableMcpServers = false;
    enableLlmAgents = false;
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Allow unfree packages for the Home Manager profile
  nixpkgs.config.allowUnfree = true;
}
