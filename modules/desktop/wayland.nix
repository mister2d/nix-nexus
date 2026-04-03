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
  # This is critical for shell features, screen sharing (Pipewire), and GTK integration.
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    # Ensure standard portals are present for all sessions
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];

    # Configuration is scoped per compositor to prevent conflicts
    config = {
      common.default = [ "gtk" ];

      # Sway uses the wlroots and GTK portals
      sway.default = lib.mkForce [
        "wlr"
        "gtk"
      ];

      # Niri uses the GNOME portal for many features
      niri.default = [
        "gnome"
        "gtk"
      ];
    };
  };
}
