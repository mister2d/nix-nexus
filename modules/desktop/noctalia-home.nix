_: {
  flake.modules.homeManager.desktop-noctalia-home =
    {
      lib,
      pkgs,
      inputs,
      ...
    }:
    {
      imports = [
        inputs.niri.homeModules.niri
        inputs.noctalia.homeModules.default
      ];

      # -----------------------------------------------------------------------
      # Niri compositor and Noctalia shell
      # -----------------------------------------------------------------------
      programs = {
        # -------------------------------------------------------------------
        # Niri compositor
        # -------------------------------------------------------------------
        niri = {
          enable = true;
          settings = {

            input = {
              keyboard.xkb.layout = "us";
              touchpad = {
                tap = true;
                natural-scroll = true;
                dwt = true;
              };
              focus-follows-mouse.enable = true;
            };

            outputs."eDP-1" = {
              mode = {
                width = 3840;
                height = 2400;
              };
              scale = 1.15;
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

            # -----------------------------------------------------------------
            # Window rules
            # Ref: https://docs.noctalia.dev/v5/getting-started/compositor-settings/niri/
            # -----------------------------------------------------------------
            window-rules = [
              # Global rounded corners.
              {
                geometry-corner-radius = {
                  top-left = 20.0;
                  top-right = 20.0;
                  bottom-left = 20.0;
                  bottom-right = 20.0;
                };
                clip-to-geometry = true;
              }
              # Float the Noctalia settings window at a fixed size.
              {
                matches = [ { app-id = "dev.noctalia.Noctalia.Settings"; } ];
                open-floating = true;
                default-column-width = {
                  fixed = 1080;
                };
                default-window-height = {
                  fixed = 920;
                };
              }
              # Per-window blur — requires niri ≥ 26.04.
              # Uncomment once the fleet niri version is confirmed.
              # {
              #   background-effect = { blur = true; xray = false; };
              # }
            ];

            # -----------------------------------------------------------------
            # Layer rules
            # Ref: https://docs.noctalia.dev/v5/getting-started/compositor-settings/niri/
            # -----------------------------------------------------------------
            layer-rules = [
              # Option 1 — blurred overview backdrop.
              # Requires backdrop.enabled = true in programs.noctalia.settings (set below).
              {
                matches = [ { namespace = "^noctalia-backdrop"; } ];
                place-within-backdrop = true;
              }
              # Blur behind bar, notification, dock, and panel surfaces.
              # Requires niri ≥ 26.04; uncomment once confirmed.
              # {
              #   matches = [ { namespace = "^noctalia-(bar-[^\"]+|notification|dock|panel)$"; } ];
              #   background-effect.xray = false;
              # }
            ];

            # -----------------------------------------------------------------
            # Startup
            # Single entry: propagate environment, restart portal, then launch shell.
            # -----------------------------------------------------------------
            spawn-at-startup = [
              {
                command = [
                  "${pkgs.bash}/bin/bash"
                  "-c"
                  ''
                    for i in $(seq 1 50); do
                      [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
                      ${pkgs.bash}/bin/sleep 0.1
                    done

                    ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd \
                      WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

                    ${pkgs.systemd}/bin/systemctl --user import-environment \
                      WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

                    ${pkgs.systemd}/bin/systemctl --user restart xdg-desktop-portal.service

                    noctalia
                  ''
                ];
              }
            ];

            environment = {
              GDK_BACKEND = "wayland";
              QT_QPA_PLATFORM = "wayland;xcb";
              QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
              MOZ_ENABLE_WAYLAND = "1";
              ELECTRON_OZONE_PLATFORM_HINT = "wayland";
              NIXOS_OZONE_WL = "1";
            };

            # -----------------------------------------------------------------
            # Keybindings
            # -----------------------------------------------------------------
            binds =
              let
                # Expand "volume-up" → ["noctalia" "msg" "volume-up"].
                noc =
                  cmd:
                  [
                    "noctalia"
                    "msg"
                  ]
                  ++ lib.strings.splitString " " cmd;
              in
              {
                # Noctalia panels
                "Mod+D".action.spawn = noc "panel-toggle launcher";
                "Mod+S".action.spawn = noc "panel-toggle control-center";
                "Mod+Comma".action.spawn = noc "settings-toggle";
                "Mod+Escape".action.spawn = noc "panel-toggle session";
                "Mod+Shift+L".action.spawn = noc "session lock";

                # Media keys — Noctalia owns volume/brightness OSD
                "XF86AudioRaiseVolume".action.spawn = noc "volume-up";
                "XF86AudioLowerVolume".action.spawn = noc "volume-down";
                "XF86AudioMute".action.spawn = noc "volume-mute";
                "XF86MonBrightnessUp".action.spawn = noc "brightness-up";
                "XF86MonBrightnessDown".action.spawn = noc "brightness-down";

                # Screenshots — Noctalia owns capture and clipboard integration
                "Print".action.spawn = noc "screenshot-region";
                "Shift+Print".action.spawn = noc "screenshot-fullscreen";

                # Applications
                "Mod+Return".action.spawn = [ "${pkgs.kitty}/bin/kitty" ];
                "Mod+Shift+Return".action.spawn = [ "${pkgs.ghostty}/bin/ghostty" ];
                "Mod+Shift+B".action.spawn = [
                  "${pkgs.bash}/bin/bash"
                  "-c"
                  "if command -v gpu-launch >/dev/null; then exec gpu-launch google-chrome-stable --ozone-platform=wayland --disable-features=ExtensionManifestV2Unsupported; else exec google-chrome-stable --ozone-platform=wayland --disable-features=ExtensionManifestV2Unsupported; fi"
                ];
                "Mod+Ctrl+B".action.spawn = [
                  "google-chrome-stable"
                  "--ozone-platform=wayland"
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
                  "BEMOJI_PICKER_CMD=\"${pkgs.wofi}/bin/wofi -W 0.3 --center -l 15 -H 32 --fn 'JetBrainsMono Nerd Font 12' --nb '#000000' --nf '#FFFFFF' --hb '#008080' --hf '#000000' --tb '#008080' --tf '#000000'\" ${pkgs.bemoji}/bin/bemoji -t -c"
                ];
                "Mod+Shift+D".action.spawn = [ "${pkgs.wdisplays}/bin/wdisplays" ];

                # Window management
                "Mod+Q".action.close-window = { };
                "Mod+Shift+E".action.quit = { };

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
              };
          };

          extraConfig = ''
            include "experimental.kdl"
          '';
        };

        # -------------------------------------------------------------------
        # Noctalia v5 shell
        # Module root: programs.noctalia (not programs.noctalia-shell)
        # Settings keys: TOML schema from https://docs.noctalia.dev/v5/
        # -------------------------------------------------------------------
        noctalia = {
          enable = true;

          settings = {
            # https://docs.noctalia.dev/v5/theming/
            theme = {
              mode = "dark";
              source = "builtin";
              builtin = "Noctalia";
            };

            # https://docs.noctalia.dev/v5/shell/
            shell = {
              telemetry_enabled = false;
              niri_overview_type_to_launch_enabled = false;
              # Register Noctalia's built-in polkit authentication agent.
              # niri-flake-polkit is disabled in desktop-niri; this fills that role.
              polkit_agent = true;
            };

            # https://docs.noctalia.dev/v5/desktop/wallpaper/
            # wallpaper.default.path is left unset; configure per-host or at
            # runtime via the wallpaper panel (persisted to settings.toml).
            wallpaper = {
              enabled = true;
              fill_mode = "crop";
            };

            # https://docs.noctalia.dev/v5/desktop/wallpaper/#backdrop
            # Pairs with the layer-rule for ^noctalia-backdrop above (Option 1).
            backdrop = {
              enabled = true;
              blur_intensity = 0.5;
              tint_intensity = 0.3;
            };

            # https://docs.noctalia.dev/v5/bar/
            bar = {
              main = {
                position = "top";
                start = [
                  "launcher"
                  "workspaces"
                ];
                center = [ "clock" ];
                end = [
                  "media"
                  "tray"
                  "notifications"
                  "network"
                  "bluetooth"
                  "volume"
                  "brightness"
                  "battery"
                  "control-center"
                  "session"
                ];
              };
            };
          };
        };
      };
    };
}
