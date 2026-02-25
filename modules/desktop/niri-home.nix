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
      gaps = 8.0; # Using float for niri-flake schema
      default-column-width.proportion = 0.5;
    };

    # Layer rules for dms-shell components.
    # These are critical for making the shell appear and render over windows correctly.
    layer-rules = [
      {
        matches = [ { namespace = "^quickshell$"; } ];
        place-within-backdrop = true;
      }
      {
        matches = [ { namespace = "dms:blurwallpaper"; } ];
        place-within-backdrop = true;
      }
    ];

    # Startup sequence for Niri + DMS
    # We spawn the shell and essential applets.
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
          "40.0"
          "-L"
          "-74.0"
        ];
      }
      # Launch Dank Material Shell
      {
        command = [
          "${inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/dms"
          "run"
        ];
      }
    ];

    # Essential Wayland environment variables to ensure DMS and portals can communicate.
    environment = {
      XDG_CURRENT_DESKTOP = "niri";
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "niri";
      QT_QPA_PLATFORM = "wayland";
      QT_QPA_PLATFORMTHEME = "gtk3";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      SDL_VIDEODRIVER = "wayland";
      CLUTTER_BACKEND = "wayland";
      GDK_BACKEND = "wayland";
      MOZ_ENABLE_WAYLAND = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      NIXOS_OZONE_WL = "1";
    };

    binds = {
      "Mod+Return".action.spawn = [ "${pkgs.alacritty}/bin/alacritty" ];
      # Browser: Matching Sway's Super+Shift+B with GPU launch selector
      "Mod+Shift+B".action.spawn = [
        "${pkgs.bash}/bin/bash"
        "-c"
        "if command -v gpu-launch >/dev/null; then exec gpu-launch google-chrome-stable --disable-features=ExtensionManifestV2Unsupported; else exec google-chrome-stable --disable-features=ExtensionManifestV2Unsupported; fi"
      ];
      # DMS Spotlight toggle
      "Mod+D".action.spawn = [
        "${inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/dms"
        "ipc"
        "call"
        "spotlight"
        "toggle"
      ];
      # Audio Selectors: Ported from Sway
      "Mod+Shift+A".action.spawn = [
        "audio-selector"
        "sink"
      ];
      "Mod+Shift+M".action.spawn = [
        "audio-selector"
        "source"
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
