{ pkgs, inputs, ... }:

let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  # RESEARCH FIX: Import official DMS Home Manager module
  imports = [ inputs.dms.homeModules.dank-material-shell ];

  # Niri Configuration (Validated at build-time by niri-flake)
  programs.niri.settings = {
    input = {
      keyboard.xkb.layout = "us";
      touchpad = {
        tap = true;
        natural-scroll = true;
        dwt = true;
      };
      focus-follows-mouse.enable = true;
    };

    xwayland-satellite.enable = false;

    outputs."eDP-1" = {
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
        x = 3344; # iGPU is renderD129 on this Z16
        y = 0;
      };
    };

    layout = {
      gaps = 8.0;
      default-column-width.proportion = 0.5;

      focus-ring = {
        enable = true;
        width = 3.0;
        active.color = "rgba(100, 100, 100, 0.7)";
        inactive.color = "rgba(50, 50, 50, 0.3)";
      };

      border.enable = false;
    };

    layer-rules = [
      { matches = [ { namespace = "^quickshell$"; } ]; }
      {
        matches = [ { namespace = "dms:blurwallpaper"; } ];
        place-within-backdrop = true;
      }
      {
        matches = [ { namespace = "wofi"; } ];
        place-within-backdrop = true;
      }
    ];

    # Startup sequence for Niri
    spawn-at-startup = [
      # ELEGANT DETERMINISTIC SYNC:
      # Services now manage their own wait-for-display via ExecStartPre.
      # We simply ensure the environment is synced once Niri is ready.
      {
        command = [
          "${pkgs.bash}/bin/bash"
          "-c"
          ''
            # 1. Wait for Niri physical socket
            for i in $(seq 1 50); do
              if [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
                break
              fi
              ${pkgs.bash}/bin/sleep 0.1
            done

            # 2. Publish environment to session manager
            # This ensures services inherit the actual socket name.
            ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd --all
            ${pkgs.systemd}/bin/systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DISPLAY
          ''
        ];
      }
      { command = [ "${pkgs.kanshi}/bin/kanshi" ]; }
    ];

    environment = {
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      MOZ_ENABLE_WAYLAND = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      NIXOS_OZONE_WL = "1";
    };

    binds = {
      "Mod+Return".action.spawn = [ "${pkgs.alacritty}/bin/alacritty" ];
      "Mod+Shift+B".action.spawn = [
        "${pkgs.bash}/bin/bash"
        "-c"
        "if command -v gpu-launch >/dev/null; then exec gpu-launch google-chrome-stable --ozone-platform=wayland --disable-features=ExtensionManifestV2Unsupported; else exec google-chrome-stable --ozone-platform=wayland --disable-features=ExtensionManifestV2Unsupported; fi"
      ];
      "Mod+Ctrl+B".action.spawn = [
        "google-chrome-stable"
        "--ozone-platform=wayland"
      ];
      "Mod+D".action.spawn = [
        "dms"
        "ipc"
        "call"
        "spotlight"
        "toggle"
      ];
      "Mod+Shift+A".action.spawn = [
        "audio-selector"
        "sink"
      ];
      "Mod+Shift+M".action.spawn = [
        "audio-selector"
        "source"
      ];
      "Mod+Alt+E".action.spawn = [
        "${pkgs.bash}/bin/bash"
        "-c"
        "BEMOJI_PICKER_CMD=\"${pkgs.wofi}/bin/wofi -W 0.3 --center -l 15 -H 32 --fn 'JetBrainsMono Nerd Font 12' --nb '#000000' --nf '#FFFFFF' --hb '#00FFFF' --hf '#000000' --tb '#00FFFF' --tf '#000000'\" ${pkgs.bemoji}/bin/bemoji -t -c"
      ];
      "Mod+Shift+D".action.spawn = [ "${pkgs.wdisplays}/bin/wdisplays" ];
      "Mod+Escape".action.spawn = [
        "${pkgs.swaylock}/bin/swaylock"
        "-f"
        "-c"
        "000000"
      ];
      "Print".action.screenshot = { };
      "Control+Print".action.screenshot-screen = { };
      "Alt+Print".action.screenshot-window = { };
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

  # DMS Configuration (Engineered based on debug/research.md blueprint)
  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true;
    dgop.package = unstable.dgop;
  };

  # Required dependencies for DMS background operations
  home.packages = with pkgs; [
    matugen
    cliphist
  ];
}
