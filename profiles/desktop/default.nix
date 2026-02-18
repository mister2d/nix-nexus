{ config, pkgs, ... }:

{
  imports = [
    ../../modules/desktop/sway.nix
    ../../modules/desktop/wayland.nix
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/theme.nix
    ../../modules/programs/flatpak.nix
  ];
}
