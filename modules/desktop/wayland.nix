# Merged into: flake.modules.nixos.desktop-default
# Configures: Wayland session variables, Qt support, and XDG desktop portals.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.desktop-default =
    {
      pkgs,
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

        # This module holds the only definition of xdg.portal.config in the
        # fleet. No compositor module sets this option, so this value needs no mkForce.
        config = {
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

          # Hyprland uses its own portal for screen capture; GTK for the rest.
          # xdg-desktop-portal-hyprland is added to extraPortals automatically
          # by programs.hyprland in desktop-hyprland.nix; no manual entry needed.
          hyprland = {
            default = [
              "hyprland"
              "gtk"
            ];
            "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
            "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
          };
        };
      };
    };
}
