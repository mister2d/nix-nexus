{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Development tools
    python3
    nodejs
    uv
    vscodium
    
    docker-compose

    # AI Coding Agents (via npx wrappers)
    (pkgs.writeShellScriptBin "gemini" "exec npx @google/gemini-cli \"$@\"")
    (pkgs.writeShellScriptBin "pi-agent" "exec npx @mariozechner/pi-coding-agent \"$@\"")
  ];

  # Direnv integration for automatic environment loading
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  virtualisation.docker.enable = true;

  # Configure npm to use a local directory for global installs
  # This fixes the "read-only filesystem" error when running 'npm install -g'
  environment.sessionVariables = {
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
  };

  # Add the local npm-global bin directory to PATH
  environment.shellInit = ''
    mkdir -p $HOME/.npm-global/bin
    export PATH=$HOME/.npm-global/bin:$PATH
  '';
}
