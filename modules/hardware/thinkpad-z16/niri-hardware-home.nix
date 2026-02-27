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
    # Wayland / Qt / Chrome Fixes
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "niri";

    # FORCE WAYLAND BACKENDS: This prevents services from falling back to X11/XCB
    # when they can't immediately find the Wayland socket.
    GDK_BACKEND = "wayland";
    CLUTTER_BACKEND = "wayland";
    QT_QPA_PLATFORM = lib.mkForce "wayland;xcb";

    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };
}
