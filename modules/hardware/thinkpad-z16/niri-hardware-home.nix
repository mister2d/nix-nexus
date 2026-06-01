_: {
  flake.modules.homeManager.hardware-z16-niri-home =
    { lib, ... }:
    {
      # ThinkPad Z16 Specific Niri Optimizations (Home Manager)

      programs.niri.settings = {
        # We no longer force a specific GPU for the compositor or clients.
        # Allowing the system/Wayland to determine the best device automatically.
      };

      # Set GPU and Wayland variables globally for the user session.
      # This ensures systemd services and sub-shells inherit the same environment.
      home.sessionVariables = {
        # WAYLAND CORE:
        GDK_BACKEND = "wayland";
        CLUTTER_BACKEND = "wayland";
        SDL_VIDEODRIVER = "wayland";
        XDG_SESSION_TYPE = "wayland";
        XDG_CURRENT_DESKTOP = "niri";
        XDG_SESSION_DESKTOP = "niri";

        # QT / GTK INTEGRATION:
        # Disable the GTK platform theme for Niri sessions to prevent X11 dependencies.
        QT_QPA_PLATFORM = "wayland;xcb";
        QT_QPA_PLATFORMTHEME = lib.mkForce "";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

        # ELECTRON / CHROME:
        ELECTRON_OZONE_PLATFORM_HINT = "wayland";
        NIXOS_OZONE_WL = "1";
        MOZ_ENABLE_WAYLAND = "1";
      };
    };
}
