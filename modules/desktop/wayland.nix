{ config, pkgs, lib, ... }:

{
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Hint electron apps to use wayland
  };

  # XDG Desktop Portal Configuration
  # This is critical for Waybar, screen sharing (Pipewire), and GTK integration.
  # We prioritize the 'wlr' portal for Sway compatibility.
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ 
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = [ "wlr" "gtk" ];
      };
      # We use mkForce to override the default NixOS sway portal configuration
      sway = lib.mkForce {
        default = [ "wlr" "gtk" ];
        "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
    };
  };
}
