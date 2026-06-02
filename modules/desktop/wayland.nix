_: {
  flake.modules.nixos.desktop-default =
    {
      pkgs,
      lib,
      ...
    }:
    {
      environment.sessionVariables = {
        NIXOS_OZONE_WL = "1"; # Hint electron apps to use wayland
      };

      # Qt Wayland Support (System-wide)
      environment.systemPackages = with pkgs; [
        qt5.qtwayland
        qt6.qtwayland
        kdePackages.qtwayland
      ];

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
        config = lib.mkForce {
          common.default = [
            "gtk"
            "gnome"
          ];

          # Sway uses the wlroots and GTK portals
          sway = {
            default = [
              "wlr"
              "gtk"
              "gnome"
            ];
            "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
            "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
          };

          # Niri uses the GNOME portal for many features
          niri.default = [
            "gnome"
            "gtk"
          ];
        };
      };
    };
}
