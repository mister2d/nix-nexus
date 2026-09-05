# Registry key: flake.modules.homeManager.hardware-petunia-hypr-home
# Configures: Hyprland monitor layout and AMD GPU environment for petunia.
# Imported by: hosts/petunia/home.nix (petunia-home).
_: {
  flake.modules.homeManager.hardware-petunia-hypr-home =
    { lib, ... }:
    {
      wayland.windowManager.hyprland.settings = {
        # ── Monitor Configuration ──────────────────────────────────────────
        # Two monitors on card1 (RDNA4 R9700): card1-DP-3 and card1-DP-4.
        # Preferred mode lets Hyprland use each display's native resolution.
        # Verify connector names after first boot: hyprctl monitors
        monitor = [
          "DP-3,preferred,0x0,1"
          "DP-4,preferred,auto-right,1"
          ",preferred,auto,1"
        ];

        # ── AMD GPU Environment ───────────────────────────────────────────
        # Additive to the env list in desktop-hyprland-home.nix.
        env = lib.mkAfter [
          "LIBVA_DRIVER_NAME,radeonsi"
          "VDPAU_DRIVER,radeonsi"
        ];

        # ── Input Overrides ───────────────────────────────────────────────
        # Desktop workstation: flat mouse acceleration, no touchpad overrides.
        input = {
          accel_profile = "flat";
        };
      };

      home.sessionVariables = {
        LIBVA_DRIVER_NAME = "radeonsi";
        VDPAU_DRIVER = "radeonsi";
      };
    };
}
