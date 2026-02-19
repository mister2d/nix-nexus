{
  pkgs,
  lib,
  ...
}:

{
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Hint electron apps to use wayland
  };

  # XDG Desktop Portal Configuration
  # This is critical for Waybar, screen sharing (Pipewire), and GTK integration.
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      common.default = [
        "wlr"
        "gtk"
      ];
      # Use mkForce to override the default NixOS sway portal configuration
      sway.default = lib.mkForce [
        "wlr"
        "gtk"
      ];
    };
  };
}
