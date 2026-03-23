{ ... }:
{
  imports = [
    ../../modules/user/bash.nix
    ../../modules/user/neovim-home.nix
  ];

  home.stateVersion = "25.11";
}
