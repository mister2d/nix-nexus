_: {
  flake.modules.nixos.hm-groot-hermes =
    {
      pkgs,
      inputs,
      homeManagerModules,
      ...
    }:
    let
      inherit (inputs.self) overlays;
      unstablePkgs = import inputs.nixpkgs-unstable {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
        overlays = [ overlays.buildFixes ];
      };
    in
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak";
        extraSpecialArgs = {
          inherit (inputs) self;
          inherit inputs;
        };
        users.groot = {
          home.stateVersion = "25.11";
          home.packages = with pkgs; [
            llm-agents.hermes-agent
            nodejs_24
            python314
            uv
            git
            btop
            htop
            openssl

            # MCP servers (mirrors dev-home.nix mcpPackages)
            context7-mcp
            github-mcp-server
            unstablePkgs.mcp-nixos
            mcp-server-time
            terraform-mcp-server
          ];
          imports = [
            inputs.nixvim.homeModules.nixvim
            homeManagerModules.user-bash
            homeManagerModules.user-terminal-home
            homeManagerModules.user-neovim-home
            homeManagerModules.user-television-home
            homeManagerModules.hermes-home
          ];
        };
      };
    };
}
