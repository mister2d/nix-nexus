{ config, pkgs, ... }:

{
  services.flatpak.enable = true;
  
  # Flatpak portal integration is handled in desktop/sway.nix
}
