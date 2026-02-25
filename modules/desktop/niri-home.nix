{ pkgs, inputs, ... }:

{
  # Since Niri is now managed by niri-flake, we use its structured settings.
  # This provides better validation and integration than raw KDL strings.
  programs.niri.settings = {
    input = {
      keyboard.xkb.layout = "us";
      touchpad = {
        tap = true;
        natural-scroll = true;
        dwt = true;
      };
    };

    outputs."eDP-1" = {
      scale = 1.0;
    };

    layout = {
      gaps = 8;
      default-column-width.proportion = 0.5;
    };

    spawn-at-startup = [
      { command = [ "${pkgs.kanshi}/bin/kanshi" ]; }
      {
        command = [
          "${pkgs.networkmanagerapplet}/bin/nm-applet"
          "--indicator"
        ];
      }
      {
        command = [
          "${pkgs.wlsunset}/bin/wlsunset"
          "-l"
          "40"
          "-L"
          "-74"
        ];
      }
      # Dank Material Shell: Using 'dms run' as the standard way to start the shell.
      # This replaces the previous 'dms-shell' guess with the confirmed binary name.
      {
        command = [
          "${inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/dms"
          "run"
        ];
      }
    ];

    binds = {
      "Mod+Return".action.spawn = [ "${pkgs.alacritty}/bin/alacritty" ];
      # DMS Spotlight toggle: Corrected the IPC command according to latest DMS documentation.
      "Mod+D".action.spawn = [
        "${inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/dms"
        "ipc"
        "call"
        "spotlight"
        "toggle"
      ];
      "Mod+Shift+E".action.quit = { };
      "Mod+Q".action.close-window = { };

      "Mod+Left".action.focus-column-left = { };
      "Mod+Right".action.focus-column-right = { };
      "Mod+Down".action.focus-window-or-workspace-down = { };
      "Mod+Up".action.focus-window-or-workspace-up = { };

      "Mod+Shift+Left".action.move-column-left = { };
      "Mod+Shift+Right".action.move-column-right = { };

      "Mod+Shift+Up".action.move-window-up = { };
      "Mod+Shift+Down".action.move-window-down = { };

      "Mod+Page_Down".action.focus-workspace-down = { };
      "Mod+Page_Up".action.focus-workspace-up = { };
      "Mod+Shift+Page_Down".action.move-window-to-workspace-down = { };
      "Mod+Shift+Page_Up".action.move-window-to-workspace-up = { };

      "XF86AudioRaiseVolume".action.spawn = [
        "${pkgs.pamixer}/bin/pamixer"
        "-i"
        "5"
      ];
      "XF86AudioLowerVolume".action.spawn = [
        "${pkgs.pamixer}/bin/pamixer"
        "-d"
        "5"
      ];
      "XF86AudioMute".action.spawn = [
        "${pkgs.pamixer}/bin/pamixer"
        "-t"
      ];

      "XF86MonBrightnessUp".action.spawn = [
        "${pkgs.brightnessctl}/bin/brightnessctl"
        "set"
        "10%+"
      ];
      "XF86MonBrightnessDown".action.spawn = [
        "${pkgs.brightnessctl}/bin/brightnessctl"
        "set"
        "10%-"
      ];

      "Print".action.spawn = [
        "${pkgs.grim}/bin/grim"
        "-g"
        "$(${pkgs.slurp}/bin/slurp)"
        "-"
      ];
    };

    window-rules = [
      {
        geometry-corner-radius = {
          bottom-left = 0.0;
          bottom-right = 0.0;
          top-left = 0.0;
          top-right = 0.0;
        };
        clip-to-geometry = true;
      }
    ];
  };
}
