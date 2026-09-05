# Host: avina (NixOS x86_64 Proxmox LXC server).
# Registry key: flake.modules.homeManager.avina-home
# Composes: user-bash, user-fish, user-neovim-home, user-herdr-home.
_: {
  flake.modules.homeManager.avina-home =
    { homeManagerModules, ... }:
    {
      imports = [
        homeManagerModules.user-bash
        homeManagerModules.user-fish
        homeManagerModules.user-neovim-home
        homeManagerModules.user-herdr-home
      ];

      home.stateVersion = "25.11";
    };
}
