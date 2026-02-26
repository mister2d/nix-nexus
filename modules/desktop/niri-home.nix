{ pkgs, ... }:

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
      # Enable mouse focus behavior (matching Sway)
      focus-follows-mouse.enable = true;
    };

    # XWayland integration: Disabled to ensure a pure Wayland environment.
    xwayland-satellite.enable = false;

    # Replicating Sway output configuration for exact positioning and scaling.
    outputs."eDP-1" = {
      # Set scaling to 1.15 as requested for the ThinkPad Z16 OLED
      scale = 1.15;
      mode = {
        width = 3840;
        height = 2400;
      };
      position = {
        x = 0;
        y = 0;
      };
    };

    outputs."DP-1" = {
      scale = 1.0;
      mode = {
        width = 3440;
        height = 1440;
      };
      position = {
        x = 3344; # Calculated logical offset from eDP-1 (3840 / 1.15)
        y = 0;
      };
    };

    layout = {
      gaps = 8.0; # Using float for niri-flake schema
      default-column-width.proportion = 0.5;

      # Subtle Focus Ring:
      # We use a soft material-themed grey that compliments the Z16's aesthetic.
      focus-ring = {
        enable = true;
        width = 3.0;
        # Soft, semi-transparent material grey (DMS-like)
        active.color = "rgba(100, 100, 100, 0.7)";
        inactive.color = "rgba(50, 50, 50, 0.3)";
      };

      border.enable = false;
    };

    # Layer rules for dms-shell components and utilities.
    # These are critical for making the shell and selectors render correctly.
    layer-rules = [
      {
        matches = [ { namespace = "^quickshell$"; } ];
      }
      {
        matches = [ { namespace = "dms:blurwallpaper"; } ];
        place-within-backdrop = true;
      }
      # Ensure wofi (GPU selector) is visible and doesn't hang
      {
        matches = [ { namespace = "wofi"; } ];
        place-within-backdrop = true;
      }
    ];

    # Startup sequence for Niri + DMS
    spawn-at-startup = [
      # DETERMINISTIC SYNC:
      # We use a blocking check for the Wayland socket, then signal
      # the systemd user manager that the graphical session is ready.
      {
        command = [
          "${pkgs.bash}/bin/bash"
          "-c"
          ''
            # 1. Wait for the socket to be physically available.
            while [ ! -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; do ${pkgs.bash}/bin/sleep 0.1; done

            # 2. Sync Niri's runtime environment to the systemd user manager.
            # This is the "proper" Wayland synchronization method.
            ${pkgs.systemd}/bin/systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DISPLAY

            # 3. Update DBus activation environment for non-systemd apps.
            ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd --all

            # 4. Restart display-dependent services now that the environment is valid.
            ${pkgs.systemd}/bin/systemctl --user restart xdg-desktop-portal.service easyeffects.service niri-flake-polkit.service

            # 5. Launch DMS
            dms run
          ''
        ];
      }
      { command = [ "${pkgs.kanshi}/bin/kanshi" ]; }
      {
        command = [
          "${pkgs.networkmanagerapplet}/bin/nm-applet"
          "--indicator"
        ];
      }
    ];

    # Essential Wayland environment variables to ensure DMS and browsers can communicate.
    environment = {
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      MOZ_ENABLE_WAYLAND = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      NIXOS_OZONE_WL = "1";
    };

    binds = {
      "Mod+Return".action.spawn = [ "${pkgs.alacritty}/bin/alacritty" ];

      # Browser: Matching Sway's Super+Shift+B with GPU launch selector
      "Mod+Shift+B".action.spawn = [
        "${pkgs.bash}/bin/bash"
        "-c"
        "if command -v gpu-launch >/dev/null; then exec gpu-launch google-chrome-stable --ozone-platform=wayland --disable-features=ExtensionManifestV2Unsupported; else exec google-chrome-stable --ozone-platform=wayland --disable-features=ExtensionManifestV2Unsupported; fi"
      ];

      # Direct Chrome launch (Integrated GPU default)
      "Mod+Ctrl+B".action.spawn = [
        "google-chrome-stable"
        "--ozone-platform=wayland"
      ];

      # DMS Spotlight toggle
      "Mod+D".action.spawn = [
        "dms"
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

      # Bemoji Picker: Ported from Sway
      "Mod+Alt+E".action.spawn = [
        "${pkgs.bash}/bin/bash"
        "-c"
        "BEMOJI_PICKER_CMD=\"${pkgs.wofi}/bin/wofi -W 0.3 --center -l 15 -H 32 --fn 'JetBrainsMono Nerd Font 12' --nb '#000000' --nf '#FFFFFF' --hb '#00FFFF' --hf '#000000' --tb '#00FFFF' --tf '#000000'\" ${pkgs.bemoji}/bin/bemoji -t -c"
      ];

      # Display Management: Ported from Sway
      "Mod+Shift+D".action.spawn = [ "${pkgs.wdisplays}/bin/wdisplays" ];

      # Screen Lock: Ported from Sway
      "Mod+Escape".action.spawn = [
        "${pkgs.swaylock}/bin/swaylock"
        "-f"
        "-c"
        "000000"
      ];

      # Screenshots: Ported from Sway, prioritizing Niri native actions
      "Print".action.screenshot = { };
      "Control+Print".action.screenshot-screen = { };
      "Alt+Print".action.screenshot-window = { };
      # Sway-compatible grim/slurp fallback
      "Control+Shift+BackSpace".action.spawn = [
        "${pkgs.bash}/bin/bash"
        "-c"
        "${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy"
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
