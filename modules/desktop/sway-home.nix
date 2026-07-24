_: {
  flake.modules.homeManager.desktop-sway-home =
    {
      pkgs,
      lib,
      ...
    }:
    let
      mod = "Mod4";
      bg = "#000000";
      fg = "#FFFFFF";
      inactive = "#333333";
      urgent = "#AA00AA";
    in
    {
      # Intelligent wlsunset wrapper for geolocation and fixed temperature presets
      xdg.configFile."sway/scripts/light.sh" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          # Intelligent wlsunset wrapper managed by Home Manager
          set -euo pipefail

          # Args: [auto|reset|2500|3000|4000|5000]
          MODE="''${1:-auto}"
          CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/wlsunset"
          COORD_CACHE="$CACHE_DIR/coords.json"

          mkdir -p "$CACHE_DIR"

          # Kill existing instances (handled by script for atomic switch)
          pkill wlsunset || true
          # Small sleep to allow wlsunset to release the Wayland surface
          sleep 0.2

          if [ "$MODE" = "reset" ]; then
              exit 0
          fi

          get_coords() {
              # Cache coordinates for 24 hours to minimize API calls and handle offline use
              if [ ! -f "$COORD_CACHE" ] || [ "$(find "$COORD_CACHE" -mmin +1440)" ]; then
                  if CONTENT=$(${pkgs.curl}/bin/curl -s --connect-timeout 5 http://ip-api.com/json/); then
                      if echo "$CONTENT" | ${pkgs.jq}/bin/jq -e '.status == "success"' >/dev/null; then
                          echo "$CONTENT" > "$COORD_CACHE"
                      fi
                  fi
              fi

              if [ -f "$COORD_CACHE" ]; then
                  LAT=$(${pkgs.jq}/bin/jq -r .lat "$COORD_CACHE")
                  LON=$(${pkgs.jq}/bin/jq -r .lon "$COORD_CACHE")
              else
                  # Fallback to Denver, CO if API and cache fail
                  LAT="39.7"
                  LON="-105.0"
              fi
          }

          case "$MODE" in
              auto)
                  get_coords
                  exec ${pkgs.wlsunset}/bin/wlsunset -l "$LAT" -L "$LON"
                  ;;
              2500|3000|4000|5000)
                  get_coords
                  # Use a 1-degree difference to ensure wlsunset doesn't treat them as identical/invalid
                  # and provide location to ensure it initializes the protocol correctly.
                  TEMP_LOW="$MODE"
                  TEMP_HIGH=$((MODE + 1))
                  exec ${pkgs.wlsunset}/bin/wlsunset -l "$LAT" -L "$LON" -t "$TEMP_LOW" -T "$TEMP_HIGH"
                  ;;
              *)
                  echo "Unknown mode: $MODE"
                  exit 1
                  ;;
          esac
        '';
      };

      wayland.windowManager.sway = {
        enable = true;
        systemd.enable = true;

        # Disable the config check because it runs in a restricted sandbox
        # that doesn't have access to DBus, causing build failures when
        # environment commands are in the session wrapper.
        checkConfig = false;

        extraSessionCommands = ''
          # Pre-initialize common variables (excluding WAYLAND_DISPLAY)
          export XDG_CURRENT_DESKTOP=sway
          export XDG_SESSION_DESKTOP=sway
          export XDG_SESSION_TYPE=wayland

          # Synchronize the Wayland environment to DBus and Systemd once per login.
          # This captures WAYLAND_DISPLAY from the session wrapper.
          systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_DATA_DIRS
          dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_DATA_DIRS
        '';

        config = {
          modifier = mod;
          terminal = "${pkgs.kitty}/bin/kitty";
          menu = "bemenu-run -H 32 -l 15 -W 0.3 --center --fn 'JetBrainsMono Nerd Font 12' --nb '#000000' --nf '#FFFFFF' --hb '#00AAAA' --hf '#000000' --tb '#00AAAA' --tf '#000000'";

          bars = [ ];

          window = {
            border = 2;
            titlebar = false;
          };

          floating = {
            border = 2;
            titlebar = false;
          };

          fonts = {
            names = [ "JetBrainsMono Nerd Font" ];
            size = 10.0;
          };

          gaps = {
            inner = 10;
            outer = 0;
            smartGaps = true;
          };

          colors = {
            focused = {
              border = "#00AAAA";
              background = bg;
              text = fg;
              indicator = "#00AAAA";
              childBorder = "#00AAAA";
            };
            focusedInactive = {
              border = inactive;
              background = bg;
              text = fg;
              indicator = inactive;
              childBorder = inactive;
            };
            unfocused = {
              border = inactive;
              background = bg;
              text = fg;
              indicator = inactive;
              childBorder = inactive;
            };
            urgent = {
              border = urgent;
              background = bg;
              text = fg;
              indicator = urgent;
              childBorder = urgent;
            };
            placeholder = {
              border = bg;
              background = bg;
              text = fg;
              indicator = bg;
              childBorder = bg;
            };
            background = bg;
          };

          output = {
            "*" = {
              scale = "1.0";
              bg = "${bg} solid_color";
            };
          };

          input = {
            "type:touchpad" = {
              tap = "enabled";
              natural_scroll = "enabled";
              click_method = "clickfinger";
            };
            "type:keyboard" = {
              xkb_layout = "us";
              repeat_delay = "300";
              repeat_rate = "20";
            };
          };

          keybindings = lib.mkOptionDefault {
            # Focus (Vim + Arrow)
            "${mod}+j" = "focus left";
            "${mod}+k" = "focus down";
            "${mod}+l" = "focus up";
            "${mod}+semicolon" = "focus right";
            "${mod}+Left" = "focus left";
            "${mod}+Down" = "focus down";
            "${mod}+Up" = "focus up";
            "${mod}+Right" = "focus right";

            # Move (Vim + Arrow)
            "${mod}+Shift+j" = "move left";
            "${mod}+Shift+k" = "move down";
            "${mod}+Shift+l" = "move up";
            "${mod}+Shift+semicolon" = "move right";
            "${mod}+Shift+Left" = "move left";
            "${mod}+Shift+Down" = "move down";
            "${mod}+Shift+Up" = "move up";
            "${mod}+Shift+Right" = "move right";

            # Layout
            "${mod}+h" = "split h";
            "${mod}+v" = "split v";
            "${mod}+f" = "fullscreen toggle";
            "${mod}+s" = "layout stacking";
            "${mod}+w" = "layout tabbed";
            "${mod}+e" = "layout toggle split";
            "${mod}+Shift+space" = "floating toggle";
            "${mod}+space" = "focus mode_toggle";
            "${mod}+a" = "focus parent";

            # Workspaces
            "${mod}+1" = "workspace number 1";
            "${mod}+2" = "workspace number 2";
            "${mod}+3" = "workspace number 3";
            "${mod}+4" = "workspace number 4";
            "${mod}+5" = "workspace number 5";
            "${mod}+6" = "workspace number 6";
            "${mod}+7" = "workspace number 7";
            "${mod}+8" = "workspace number 8";
            "${mod}+9" = "workspace number 9";
            "${mod}+0" = "workspace number 10";

            "${mod}+Shift+1" = "move container to workspace number 1";
            "${mod}+Shift+2" = "move container to workspace number 2";
            "${mod}+Shift+3" = "move container to workspace number 3";
            "${mod}+Shift+4" = "move container to workspace number 4";
            "${mod}+Shift+5" = "move container to workspace number 5";
            "${mod}+Shift+6" = "move container to workspace number 6";
            "${mod}+Shift+7" = "move container to workspace number 7";
            "${mod}+Shift+8" = "move container to workspace number 8";
            "${mod}+Shift+9" = "move container to workspace number 9";
            "${mod}+Shift+0" = "move container to workspace number 10";

            # System
            "${mod}+Shift+c" = "reload";

            # Media
            "XF86AudioRaiseVolume" = "exec pamixer -i 2";
            "XF86AudioLowerVolume" = "exec pamixer -d 2";
            "XF86AudioMute" = "exec pamixer -t";
            "XF86AudioMicMute" = "exec pamixer --default-source -t";
            "XF86MonBrightnessUp" = "exec brightnessctl set 2%+";
            "XF86MonBrightnessDown" = "exec brightnessctl set 2%-";

            # Audio Selector
            "${mod}+Shift+a" = "exec audio-selector sink";
            "${mod}+Shift+m" = "exec audio-selector source";

            # Apps
            "${mod}+Return" = "exec ${pkgs.kitty}/bin/kitty";
            "${mod}+Shift+Return" = "exec ${pkgs.ghostty}/bin/ghostty";
            "${mod}+Shift+b" =
              "exec env DRI_PRIME=1 google-chrome-stable --ozone-platform-hint=auto --enable-features=WebRTCPipeWireCapturer --disable-features=ExtensionManifestV2Unsupported";
            "${mod}+Shift+d" = "exec wdisplays";
            "${mod}+Alt+e" =
              "exec BEMOJI_PICKER_CMD=\"bemenu -W 0.3 --center -l 15 -H 32 --fn 'JetBrainsMono Nerd Font 12' --nb '#000000' --nf '#FFFFFF' --hb '#00AAAA' --hf '#000000' --tb '#00AAAA' --tf '#000000'\" ${pkgs.bemoji}/bin/bemoji -n -c";
            "${mod}+Shift+e" = "exec swaynag -t warning -m 'Exit sway?' -b 'Yes' 'swaymsg exit'";
            "${mod}+Escape" = "exec swaylock -f -c 000000";

            # Screenshots
            "Control+Shift+BackSpace" =
              "exec ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy";
            "Print" = "exec ${pkgs.grim}/bin/grim - | ${pkgs.wl-clipboard}/bin/wl-copy";
            "Shift+Print" =
              "exec ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy";
            "${mod}+Print" = "exec ${pkgs.grim}/bin/grim - | ${pkgs.wl-clipboard}/bin/wl-copy";

            # Night Light (wlsunset) Mode
            "${mod}+Shift+u" =
              "mode \"night-light\"; exec 'swaynag -t warning -m \"Night Light Mode: (a)uto, (r)eset, (2)500K, (3)000K, (4)4000K, (5)5000K\"'";

            # Resize
            "${mod}+r" = "mode \"resize\"";
          };

          modes = {
            resize = {
              "j" = "resize shrink width 10 px or 10 ppt";
              "k" = "resize grow height 10 px or 10 ppt";
              "l" = "resize shrink height 10 px or 10 ppt";
              "semicolon" = "resize grow width 10 px or 10 ppt";
              "Left" = "resize shrink width 10 px or 10 ppt";
              "Down" = "resize grow height 10 px or 10 ppt";
              "Up" = "resize shrink height 10 px or 10 ppt";
              "Right" = "resize grow width 10 px or 10 ppt";
              "Return" = "mode \"default\"";
              "Escape" = "mode \"default\"";
              "${mod}+r" = "mode \"default\"";
            };
            "night-light" = {
              # Use single quotes around complex exec commands to ensure Sway
              # correctly identifies the 'mode "default"' command as a separate action.
              # We pkill swaynag to dismiss the menu.
              # light.sh handles wlsunset lifecycle and geolocation.
              "a" = "exec 'pkill swaynag || true; ~/.config/sway/scripts/light.sh auto', mode \"default\"";
              "r" = "exec 'pkill swaynag || true; ~/.config/sway/scripts/light.sh reset', mode \"default\"";
              "2" = "exec 'pkill swaynag || true; ~/.config/sway/scripts/light.sh 2500', mode \"default\"";
              "3" = "exec 'pkill swaynag || true; ~/.config/sway/scripts/light.sh 3000', mode \"default\"";
              "4" = "exec 'pkill swaynag || true; ~/.config/sway/scripts/light.sh 4000', mode \"default\"";
              "5" = "exec 'pkill swaynag || true; ~/.config/sway/scripts/light.sh 5000', mode \"default\"";
              "Return" = "exec 'pkill swaynag || true', mode \"default\"";
              "Escape" = "exec 'pkill swaynag || true', mode \"default\"";
            };
          };

          startup = [
            # Restart core services and Waybar (explicitly set always=false to prevent reload spam)
            {
              command = "systemctl --user restart xdg-desktop-portal.service easyeffects.service > /dev/null 2>&1; systemctl --user start waybar.service > /dev/null 2>&1";
              always = false;
            }
            {
              command = "kanshi > /dev/null 2>&1";
              always = false;
            }
            {
              command = "${
                (import ../../lib/custom-scripts.nix { inherit pkgs; }).battery-alert
              }/bin/battery-alert > /dev/null 2>&1";
              always = false;
            }
            {
              command = "nm-applet --indicator > /dev/null 2>&1";
              always = false;
            }
            {
              command = "wl-paste -t text --watch clipman store --no-persist > /dev/null 2>&1";
              always = false;
            }
          ];

          window.commands = [
            {
              criteria = {
                window_role = "pop-up";
              };
              command = "floating enable";
            }
            {
              criteria = {
                window_type = "dialog";
              };
              command = "floating enable";
            }
          ];
        };

        extraConfig = ''
          bindswitch --reload --locked lid:on exec swaylock -f -c 000000
        '';
      };

      # Complementary services for Sway
      services.swayidle = {
        enable = true;
        timeouts = [
          {
            timeout = 600;
            command = "${pkgs.swaylock}/bin/swaylock -f -c 000000";
          }
          {
            timeout = 900;
            command = "${pkgs.sway}/bin/swaymsg \"output * dpms off\"";
            resumeCommand = "${pkgs.sway}/bin/swaymsg \"output * dpms on\"";
          }
        ];
        events = [
          {
            event = "before-sleep";
            command = "${pkgs.swaylock}/bin/swaylock -f -c 000000";
          }
        ];
      };

      # Lock screen
      programs.swaylock = {
        enable = true;
        settings = {
          color = "000000";
          show-failed-attempts = true;
        };
      };
    };
}
