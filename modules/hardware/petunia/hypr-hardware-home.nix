# Registry key: flake.modules.homeManager.hardware-petunia-hypr-home
# Configures: Hyprland monitor layout and AMD GPU environment for petunia.
# Imported by: hosts/petunia/home.nix (petunia-home).
_: {
  flake.modules.homeManager.hardware-petunia-hypr-home =
    { lib, ... }:
    let
      mkEnv = name: value: {
        _args = [
          name
          value
        ];
      };
    in
    {
      wayland.windowManager.hyprland.settings = {
        # ── Monitor Configuration ──────────────────────────────────────────
        # Two monitors on card1 (RDNA4 R9700): card1-DP-3 and card1-DP-4.
        # Preferred mode lets Hyprland use each display's native resolution.
        # Verify connector names after first boot: hyprctl monitors
        monitor = [
          {
            output = "DP-3";
            mode = "preferred";
            position = "0x0";
            scale = 1;
          }
          {
            output = "DP-4";
            mode = "preferred";
            position = "auto-right";
            scale = 1;
          }
          {
            output = "";
            mode = "preferred";
            position = "auto";
            scale = 1;
          }
        ];

        # ── AMD GPU Environment ───────────────────────────────────────────
        # Additive to the env list in desktop-hyprland-home.nix.
        env = lib.mkAfter [
          (mkEnv "LIBVA_DRIVER_NAME" "radeonsi")
          (mkEnv "VDPAU_DRIVER" "radeonsi")
        ];

        # ── Input Overrides ───────────────────────────────────────────────
        # Desktop workstation: flat mouse acceleration, no touchpad overrides.
        config.input.accel_profile = "flat";
      };

      home.sessionVariables = {
        LIBVA_DRIVER_NAME = "radeonsi";
        VDPAU_DRIVER = "radeonsi";
      };
    };
}
