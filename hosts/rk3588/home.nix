_: {
  flake.modules.homeManager.rk3588-home =
    {
      pkgs,
      homeManagerModules,
      ...
    }:

    {
      imports = [
        homeManagerModules.user-bash
        homeManagerModules.user-fish
        homeManagerModules.user-neovim-home
        homeManagerModules.user-terminal-home
        homeManagerModules.user-terminal-oled-home
        homeManagerModules.user-television-home
        homeManagerModules.user-dev-home
        homeManagerModules.user-herdr-home
      ];

      # Home Configuration
      home = {
        username = "groot";
        # Standard Armbian home path for SBC fleet
        homeDirectory = "/home/groot";
        stateVersion = "25.11"; # Matching codebase standard for 2026

        # Other tools (git, htop, etc.) are included via imported modules.
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
    };
}
