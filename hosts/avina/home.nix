{ ... }:
{
  imports = [
    ../../modules/user/bash.nix
    ../../modules/user/neovim-home.nix
    ../../modules/user/dev-home.nix
  ];

  programs.dev-home = {
    enable = true;
    enableMcpServers = false;
    enableLlmAgents = false;
  };

  home.stateVersion = "25.11";
}
