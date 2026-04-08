{ ... }:
{
  # ============================================================================
  # Sway Aspect: The Visual Cortex
  # ============================================================================

  den.aspects.sway-aspect = {
    nixos = { config, lib, pkgs, ... }: {
      programs.sway = {
        enable = true;
        wrapperFeatures.gtk = true;
        extraPackages = with pkgs; [ swaylock swayidle foot wofi kanshi ];
      };

      services.greetd = {
        enable = true;
        settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --cmd sway";
      };

      environment.etc."sway/config.d/touchpad.conf".text = ''
        input "type:touchpad" { tap enabled; natural_scroll enabled; click_method clickfinger; }
      '';

      # Home Manager Configuration for ddukes
      home-manager.users.ddukes = {
        xdg.configFile."sway/scripts/light.sh" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            MODE="''${1:-auto}"
            # ... light script content ...
            pkill wlsunset || true
            if [ "$MODE" = "reset" ]; then exit 0; fi
            LAT="39.7"; LON="-105.0"
            case "$MODE" in
                auto) exec ${pkgs.wlsunset}/bin/wlsunset -l "$LAT" -L "$LON" ;;
                2500|3000|4000|5000) exec ${pkgs.wlsunset}/bin/wlsunset -l "$LAT" -L "$LON" -t "$MODE" -T $((MODE + 1)) ;;
            esac
          '';
        };

        wayland.windowManager.sway = {
          enable = true;
          systemd.enable = true;
          checkConfig = false;
          config = let
            mod = "Mod4";
            bg = "#000000";
          in {
            modifier = mod;
            terminal = "${pkgs.kitty}/bin/kitty";
            menu = "${pkgs.bemenu}/bin/bemenu-run";
            window.border = 2;
            gaps.inner = 10;
            keybindings = lib.mkOptionDefault {
                "${mod}+Return" = "exec ${pkgs.kitty}/bin/kitty";
                "${mod}+Shift+e" = "exec swaynag -t warning -m 'Exit sway?' -b 'Yes' 'swaymsg exit'";
            };
          };
        };
      };
    };
  };
}
