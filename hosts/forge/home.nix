_: {
  flake.modules.homeManager.forge-home =
    {
      pkgs,
      inputs,
      homeManagerModules,
      ...
    }:

    {
      imports = [
        homeManagerModules.user-bash
        homeManagerModules.user-neovim-home
        homeManagerModules.user-terminal-home
        homeManagerModules.user-terminal-oled-home
        homeManagerModules.user-television-home
        homeManagerModules.user-dev-home
      ];

      # Home Configuration
      home = {
        username = "groot";
        homeDirectory = "/home/groot";
        stateVersion = "25.11";

        # Basic packages
        packages = with pkgs; [
          zstd
          curl
          wget
          htop
          nvtopPackages.nvidia # For monitoring the Quadro T2000
        ];
      };

      # Development Home Profile
      # Enabled MCP servers and LLM agents because i7-9850H supports AVX2
      programs.dev-home = {
        enable = true;
        enableMcpServers = true;
        enableLlmAgents = true;
      };

      # Let Home Manager install and manage itself.
      programs.home-manager.enable = true;

      # Allow unfree packages for the Home Manager profile
      nixpkgs.config.allowUnfree = true;

      # Add Model Control Protocol (MCP) server packages via overlay
      nixpkgs.overlays = [ inputs.mcp-servers-nix.overlays.default ];
    };
}
