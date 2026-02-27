{ lib, ... }:

{
  # ThinkPad Z16 Specific Niri Optimizations (Home Manager)
  # NOTE: On this specific Z16, lspci/DRI paths show:
  # - dGPU (6500M): pci-0000:03:00.0 -> renderD128
  # - iGPU (680M):  pci-0000:67:00.0 -> renderD129

  programs.niri.settings = {
    # Force Niri to use the Integrated GPU (680M) for the compositor.
    # On THIS Z16, the iGPU is renderD129.
    debug.render-drm-device = "/dev/dri/renderD129";

    # Force all clients to Integrated GPU by default for battery savings.
    # Correct PCI ID format for DRI_PRIME is 'pci-0000:67:00.0'
    environment.DRI_PRIME = "pci-0000:67:00.0";

    # Vulkan GPU selection: Prevents apps from probing the dGPU.
    environment.MESA_VK_DEVICE_SELECT = "pci-0000:67:00.0";
  };

  # Set GPU and Wayland variables globally for the user session.
  # This ensures systemd services and sub-shells inherit the same environment.
  home.sessionVariables = {
    DRI_PRIME = lib.mkForce "pci-0000:67:00.0";
    MESA_VK_DEVICE_SELECT = lib.mkForce "pci-0000:67:00.0";

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
