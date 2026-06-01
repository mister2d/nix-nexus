_: {
  flake.modules.homeManager.hardware-z16-sway-home = _: {
    # ThinkPad Z16 Specific Sway Optimizations (Home Manager)
    wayland.windowManager.sway.config = {
      output = {
        # Explicit fallbacks for the Z16 layout
        "eDP-1" = {
          scale = "1.15";
          pos = "0 0";
          res = "3840x2400";
        };
        "DP-1" = {
          scale = "1.0";
          pos = "3344 0";
          res = "3440x1440";
        };
      };

      # Workspace assignments for sequential numbering
      # Laptop (eDP-1) gets 1-5, External (DP-1) gets 6-10
      workspaceOutputAssign = [
        {
          workspace = "1";
          output = "eDP-1";
        }
        {
          workspace = "2";
          output = "eDP-1";
        }
        {
          workspace = "3";
          output = "eDP-1";
        }
        {
          workspace = "4";
          output = "eDP-1";
        }
        {
          workspace = "5";
          output = "eDP-1";
        }
        {
          workspace = "6";
          output = "DP-1";
        }
        {
          workspace = "7";
          output = "DP-1";
        }
        {
          workspace = "8";
          output = "DP-1";
        }
        {
          workspace = "9";
          output = "DP-1";
        }
        {
          workspace = "10";
          output = "DP-1";
        }
      ];

      input = {
        "type:touchpad" = {
          tap = "enabled";
          natural_scroll = "enabled";
          drag = "enabled";
          drag_lock = "disabled";
          dwt = "enabled";
          middle_emulation = "enabled";
          accel_profile = "adaptive";
          pointer_accel = "0.0";
          # The Z16 haptic pad works best with clickfinger for buttons
          click_method = "clickfinger";
        };
      };
    };
  };
}
