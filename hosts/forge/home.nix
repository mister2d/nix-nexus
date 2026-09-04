_: {
  flake.modules.homeManager.forge-home =
    {
      pkgs,
      inputs,
      homeManagerModules,
      ...
    }:

    {
      imports = [ homeManagerModules.user-standalone-home ];

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

      # Add Model Control Protocol (MCP) server packages via overlay
      nixpkgs.overlays = [ inputs.mcp-servers-nix.overlays.default ];
    };
}
