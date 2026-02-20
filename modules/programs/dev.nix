{
  pkgs,
  inputs,
  ...
}:

{
  # Add Model Control Protocol (MCP) server packages via overlay
  nixpkgs.overlays = [ inputs.mcp-servers-nix.overlays.default ];

  environment = {
    systemPackages = with pkgs; [
      # Development tools
      devbox
      python3
      nodejs
      uv
      vscodium

      docker-compose

      # MCP Servers
      context7-mcp
      mcp-nixos
      mcp-server-fetch
      mcp-server-git
      mcp-server-sequential-thinking
      mcp-server-time
      terraform-mcp-server

      # AI Coding Agents (via npx wrappers)
      (pkgs.writeShellScriptBin "gemini" "exec npx @google/gemini-cli \"$@\"")
      (pkgs.writeShellScriptBin "pi-agent" "exec npx @mariozechner/pi-coding-agent \"$@\"")
    ];

    # Configure npm to use a local directory for global installs
    # This fixes the "read-only filesystem" error when running 'npm install -g'
    sessionVariables = {
      NPM_CONFIG_PREFIX = "$HOME/.npm-global";
    };

    # Add the local npm-global bin directory to PATH
    shellInit = ''
      mkdir -p $HOME/.npm-global/bin
      export PATH=$HOME/.npm-global/bin:$PATH
    '';
  };

  # Direnv integration for automatic environment loading
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  virtualisation.docker.enable = true;
}
