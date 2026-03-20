{ pkgs, ... }:

{
  # ThinkPad Z16 (sweet16) Host-Specific Home Manager Profile
  # This profile merges shared user settings with hardware-specific optimizations
  # for the OLED display, haptic touchpad, and docking behavior.
  imports = [
    ../../modules/user/home.nix
    ../../modules/hardware/thinkpad-z16/kanshi-home.nix
    ../../modules/hardware/thinkpad-z16/sway-hardware-home.nix
  ];

  # Resource Monitor with AMD GPU support
  programs.btop.package = pkgs.btop.override { rocmSupport = true; };
}
