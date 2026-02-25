{ pkgs, ... }:

{
  # Since Niri doesn't have a Home Manager module yet, we manage its config
  # file directly via KDL (Niri's native configuration language).
  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "us"
            }
        }
        touchpad {
            tap
            natural-scroll
            dwt
        }
    }

    output "eDP-1" {
        scale 1.0
    }

    layout {
        gaps 8
        default-column-width { proportion 0.5; }
    }

    spawn-at-startup "${pkgs.kanshi}/bin/kanshi"
    spawn-at-startup "${pkgs.networkmanagerapplet}/bin/nm-applet" "--indicator"
    spawn-at-startup "${pkgs.wlsunset}/bin/wlsunset" "-l" "40" "-L" "-74"
    spawn-at-startup "dms-shell"

    binds {
        Mod+Return { spawn "${pkgs.alacritty}/bin/alacritty"; }
        Mod+D { spawn "dms-shell" "--toggle-launcher"; }
        Mod+Shift+E { quit; }
        Mod+Q { close-window; }

        Mod+Left { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Down { focus-window-or-workspace-down; }
        Mod+Up { focus-window-or-workspace-up; }

        Mod+Shift+Left { move-column-left; }
        Mod+Shift+Right { move-column-right; }

        Mod+Shift+Up { move-window-up; }
        Mod+Shift+Down { move-window-down; }

        Mod+Page_Down { focus-workspace-down; }
        Mod+Page_Up { focus-workspace-up; }
        Mod+Shift+Page_Down { move-window-to-workspace-down; }
        Mod+Shift+Page_Up { move-window-to-workspace-up; }

        XF86AudioRaiseVolume { spawn "${pkgs.pamixer}/bin/pamixer" "-i" "5"; }
        XF86AudioLowerVolume { spawn "${pkgs.pamixer}/bin/pamixer" "-d" "5"; }
        XF86AudioMute { spawn "${pkgs.pamixer}/bin/pamixer" "-t"; }

        XF86MonBrightnessUp { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "10%+"; }
        XF86MonBrightnessDown { spawn "${pkgs.brightnessctl}/bin/brightnessctl" "set" "10%-"; }

        Print { spawn "${pkgs.grim}/bin/grim" "-g" "$(${pkgs.slurp}/bin/slurp)" "-"; }
    }

    window-rule {
        geometry-corner-radius 0
        clip-to-geometry true
    }
  '';
}
