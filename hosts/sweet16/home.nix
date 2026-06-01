{ pkgs, homeManagerModules, ... }:

{
  # ThinkPad Z16 (sweet16) Host-Specific Home Manager Profile
  # This profile merges shared user settings with hardware-specific optimizations
  # for the OLED display, haptic touchpad, and docking behavior.
  imports = [
    ../../modules/user/home.nix
    homeManagerModules.hardware-z16-kanshi-home
    homeManagerModules.hardware-z16-sway-home

    # Desktop Environments & Customization
    ../../modules/desktop/sway-home.nix
    ../../modules/desktop/waybar-home.nix
  ];

  # Resource Monitor with AMD GPU support
  programs.btop.package = pkgs.btop.override { rocmSupport = true; };
}
