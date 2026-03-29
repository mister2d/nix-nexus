{
  den,
  inputs,
  lib,
  ...
}:
{
  # Niri + DMS Aspect — Unified System & User Configuration
  # ============================================================================

  den.aspects.niri-aspect = lib.mkForce {
    # Hardware-specific overrides via provides
    provides.petunia = den.aspects.niri-aspect-petunia;

    # System-level configuration
    nixos =
      { pkgs, lib, ... }:
      let
        unstable = import inputs.nixpkgs-unstable {
          inherit (pkgs.stdenv.hostPlatform) system;
          config.allowUnfree = true;
        };
      in
      {
        nixpkgs.overlays = [
          (_final: prev: {
            niri = prev.niri.overrideAttrs (_old: {
              doCheck = false;
            });
          })
        ];

        imports = [
          inputs.dms.nixosModules.default
          inputs.niri.nixosModules.niri
        ];

        programs.niri = {
          enable = true;
          package = lib.mkForce (
            pkgs.niri.overrideAttrs (_old: {
              doCheck = false;
            })
          );
        };

        programs.dank-material-shell = {
          enable = true;
          dgop.package = unstable.dgop;
          enableSystemMonitoring = true;
          enableVPN = true;
          enableDynamicTheming = true;
          enableAudioWavelength = true;
          enableCalendarEvents = true;
          enableClipboardPaste = true;
          systemd.enable = false;
        };

        systemd.user.services = {
          niri-flake-polkit.enable = false;
          easyeffects = {
            after = [ "graphical-session.target" ];
            partOf = [ "graphical-session.target" ];
            wantedBy = [ "graphical-session.target" ];
          };
        };

        hardware.graphics = {
          enable = true;
          extraPackages = with pkgs; [
            rocmPackages.clr.icd
          ];
        };

        security.polkit.enable = true;

        services = {
          accounts-daemon.enable = true;
          upower.enable = true;
          greetd = {
            enable = true;
            settings = {
              default_session = {
                command = lib.mkDefault "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --cmd niri-session";
                user = "greeter";
              };
            };
          };
        };

        environment.systemPackages = with pkgs; [
          unstable.dsearch
          unstable.xwayland-satellite
          qt6.qtwayland
          kdePackages.qtwayland
        ];
      };

    # User-level configuration
    homeManager =
      { lib, pkgs, ... }:
      let
        unstable = import inputs.nixpkgs-unstable {
          inherit (pkgs.stdenv.hostPlatform) system;
          config.allowUnfree = true;
        };
      in
      {
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

          spawn-at-startup = lib.mkAfter [
            {
              command = [
                "${pkgs.bash}/bin/bash"
                "-c"
                ''
                  for i in $(seq 1 50); do
                    if [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
                      break
                    fi
                    ${pkgs.bash}/bin/sleep 0.1
                  done
                  ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
                  ${pkgs.systemd}/bin/systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
                  ${pkgs.systemd}/bin/systemctl --user restart easyeffects.service xdg-desktop-portal.service
                ''
              ];
            }
            { command = [ "${pkgs.kanshi}/bin/kanshi" ]; }
          ];

          environment = {
            GDK_BACKEND = "wayland";
            DISPLAY = "";
            QT_QPA_PLATFORM = "wayland;xcb";
            QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
            MOZ_ENABLE_WAYLAND = "1";
            ELECTRON_OZONE_PLATFORM_HINT = "wayland";
            NIXOS_OZONE_WL = "1";
          };

          binds = {
            "Mod+Return".action.spawn = [ "${pkgs.kitty}/bin/kitty" ];
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
              "BEMOJI_PICKER_CMD=\"${pkgs.wofi}/bin/wofi -W 0.3 --center -l 15 -H 32 --fn 'JetBrainsMono Nerd Font 12' --nb '#000000' --nf '#FFFFFF' --hb '#008080' --hf '#000000' --tb '#008080' --tf '#000000'\" ${pkgs.bemoji}/bin/bemoji -t -c"
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
              "-d"
              "5"
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

        programs.dank-material-shell = {
          enable = true;
          dgop.package = unstable.dgop;
          niri = {
            includes.enable = false;
            enableSpawn = true;
            enableKeybinds = false;
          };
        };

        home.packages = with pkgs; [
          matugen
          cliphist
        ];
      };
  };

  # ============================================================================
  # Petunia Specific Niri Optimizations
  # ============================================================================
  den.aspects.niri-aspect-petunia = {
    homeManager = _: {
      programs.niri.settings = {
        outputs = {
          "DP-1" = {
            mode = {
              width = 2560;
              height = 1440;
              refresh = 144.0;
            };
            variable-refresh-rate = true;
          };
        };
        input = {
          mouse = {
            accel-speed = 0.0;
            accel-profile = "flat";
          };
          keyboard = {
            xkb.layout = "us";
          };
        };
      };
    };
  };
}
