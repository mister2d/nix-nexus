# Registry key: flake.modules.homeManager.hardware-z16-hypr-home
# Configures: Hyprland monitor layout, HDR, and touchpad input for the Z16.
# Imported by: hosts/sweet16/home.nix (sweet16-home).
_: {
  flake.modules.homeManager.hardware-z16-hypr-home =
    { lib, ... }:
    let
      mkEnv = name: value: {
        _args = [
          name
          value
        ];
      };

      # Workspaces 1-5 on the laptop panel, 6-10 on the external display.
      # The first workspace of each monitor is its default.
      workspaceRule = n: {
        workspace = toString n;
        monitor = if n <= 5 then "eDP-1" else "DP-1";
        persistent = true;
      };
      workspaceRules = map (
        n: workspaceRule n // lib.optionalAttrs (n == 1 || n == 6) { default = true; }
      ) (lib.range 1 10);
    in
    {
      wayland.windowManager.hyprland.settings = {
        # ── Monitor Configuration ──────────────────────────────────────────
        # eDP-1: 3840×2400 OLED, scale 1.20, 10-bit output for HDR10.
        # DP-1:  External ultrawide 3440×1440, to the right.
        # Catchall: any other connected output at preferred mode.
        monitor = [
          # DP-1 offset = 3840 / 1.20 = 3200 scaled units.
          # @60 matches the EDID — the panel only reports 60.00Hz.
          {
            output = "eDP-1";
            mode = "3840x2400@60";
            position = "0x0";
            scale = 1.2;
            bitdepth = 10;
          }
          {
            output = "DP-1";
            mode = "3440x1440@144";
            position = "3200x0";
            scale = 1.0;
          }
          {
            output = "";
            mode = "preferred";
            position = "auto";
            scale = 1.0;
          }
        ];

        # ── Workspace Assignments ──────────────────────────────────────────
        # Matches the sway and niri profiles: 1-5 on laptop, 6-10 on external.
        workspace_rule = workspaceRules;

        config = {
          # ── Render / Color Management / HDR ─────────────────────────────
          # render.cm_enabled:  Activates color management subsystem.
          # render.cm_auto_hdr: Auto-engages HDR output for fullscreen HDR apps.
          #                     Requires bitdepth = 10 on the eDP-1 monitor.
          render = {
            cm_enabled = true;
            cm_auto_hdr = true;
          };

          # ── Z16-Specific Input Overrides ────────────────────────────────
          input.touchpad = {
            clickfinger_behavior = true; # Z16 ForcePad requires clickfinger
            scroll_factor = 1.0;
          };
        };

        # ── AMD GPU Environment ───────────────────────────────────────────
        # Additive to the env list in desktop-hyprland-home.nix.
        env = lib.mkAfter [
          (mkEnv "LIBVA_DRIVER_NAME" "radeonsi")
        ];
      };

      home.sessionVariables = {
        LIBVA_DRIVER_NAME = "radeonsi";
        VDPAU_DRIVER = "radeonsi";
      };
    };
}
