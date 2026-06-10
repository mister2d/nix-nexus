_: {
  flake.modules.homeManager.hardware-z16-hypr-home =
    { lib, ... }:
    {
      wayland.windowManager.hyprland.settings = {
        # ── Monitor Configuration ──────────────────────────────────────────
        # eDP-1: 3840×2400 OLED, scale 1.15, 10-bit output for HDR10.
        # DP-1:  External ultrawide 3440×1440, to the right.
        # Catchall: any other connected output at preferred mode.
        monitor = [
          # Scale 1.20 is the nearest preferred fractional value Hyprland v0.55
          # supports for wp_fractional_scale_v1; 1.15 was silently rounded up.
          # DP-1 offset = 3840 / 1.20 = 3200 scaled units.
          # @60 matches the EDID — the panel only reports 60.00Hz.
          "eDP-1,3840x2400@60,0x0,1.20,bitdepth,10"
          "DP-1,3440x1440@144,3200x0,1.0"
          ",preferred,auto,1.0"
        ];

        # ── Workspace Assignments ──────────────────────────────────────────
        # Matches the sway and niri profiles: 1-5 on laptop, 6-10 on external.
        workspace = [
          "1, monitor:eDP-1, default:true, persistent:true"
          "2, monitor:eDP-1, persistent:true"
          "3, monitor:eDP-1, persistent:true"
          "4, monitor:eDP-1, persistent:true"
          "5, monitor:eDP-1, persistent:true"
          "6, monitor:DP-1, default:true, persistent:true"
          "7, monitor:DP-1, persistent:true"
          "8, monitor:DP-1, persistent:true"
          "9, monitor:DP-1, persistent:true"
          "10, monitor:DP-1, persistent:true"
        ];

        # ── Render / Color Management / HDR ───────────────────────────────
        # render.cm_enabled:  Activates color management subsystem.
        # render.cm_auto_hdr: Auto-engages HDR output for fullscreen HDR apps.
        #                     Requires bitdepth,10 on the monitor line above.
        #                     Added in v0.41; requires upstream flake (nixos-25.11
        #                     ships 0.52.1 which predates the option rename).
        render = {
          cm_enabled = true;
          cm_auto_hdr = true;
        };

        # ── Z16-Specific Input Overrides ──────────────────────────────────
        input.touchpad = {
          clickfinger_behavior = true; # Z16 ForcePad requires clickfinger
          scroll_factor = 1.0;
        };

        # ── AMD GPU Environment ───────────────────────────────────────────
        # Additive to the env list in desktop-hyprland-home.nix.
        env = lib.mkAfter [
          "LIBVA_DRIVER_NAME,radeonsi"
        ];
      };

      home.sessionVariables = {
        LIBVA_DRIVER_NAME = lib.mkForce "radeonsi";
        VDPAU_DRIVER = lib.mkForce "radeonsi";
      };
    };
}
