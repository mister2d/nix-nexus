{
  pkgs,
  lib,
  ...
}:

let
  scripts = import ../programs/custom-scripts.nix { inherit pkgs; };
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    systemd.target = "sway-session.target";

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 32;
        spacing = 4;
        modules-left = [
          "sway/workspaces"
          "sway/mode"
          "sway/window"
        ];
        modules-center = [
          "custom/kanshi"
          "clock"
        ];
        modules-right = [
          "custom/system-stats"
          "memory"
          "disk"
          "pulseaudio"
          "pulseaudio#microphone"
          "network"
          "battery"
          "tray"
        ];

        "sway/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{name}";
        };

        "custom/kanshi" = {
          format = " {}";
          exec = "${pkgs.coreutils}/bin/cat /tmp/kanshi-profile 2>/dev/null || echo 'default'";
          interval = "once";
          signal = 8;
          tooltip = true;
          "tooltip-format" = "Kanshi Profile";
        };

        clock = {
          format = "{:%Y-%m-%d %H:%M:%S}";
          interval = 1;
          "tooltip-format" = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        "custom/system-stats" = {
          exec = "${scripts.system-stats}/bin/system-stats";
          return-type = "json";
          interval = 2;
          format = "{}";
        };

        memory = {
          format = "{used:0.1f}G/{total:0.1f}G ";
          interval = 5;
        };

        disk = {
          format = "{percentage_used}% ";
          path = "/";
          interval = 30;
        };

        pulseaudio = {
          format = "{volume}% {icon}";
          "format-bluetooth" = "{volume}% {icon}";
          "format-bluetooth-muted" = " {icon}";
          "format-muted" = "";
          "format-icons" = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [
              ""
              ""
              ""
            ];
          };
          "scroll-step" = 2;
          on-click = "${pkgs.pamixer}/bin/pamixer -t";
          "on-click-right" = "${scripts.audio-selector}/bin/audio-selector sink";
          "on-click-middle" = "${pkgs.pavucontrol}/bin/pavucontrol";
          tooltip = true;
          "tooltip-format" = "Output: {desc}";
        };

        "pulseaudio#microphone" = {
          format = "{format_source}";
          "format-source" = "{volume}% ";
          "format-source-muted" = "";
          "scroll-step" = 2;
          on-click = "${pkgs.pamixer}/bin/pamixer --default-source -t";
          "on-click-right" = "${scripts.audio-selector}/bin/audio-selector source";
          "on-click-middle" = "${pkgs.pavucontrol}/bin/pavucontrol";
          tooltip = true;
          "tooltip-format" = "Input: {source_desc}";
        };

        network = {
          "format-wifi" = "{essid} ({signalStrength}%) ";
          "format-ethernet" = "{ipaddr} ";
          "tooltip-format" = "{ifname} via {gwaddr} ";
          "format-linked" = "{ifname} (No IP) ";
          "format-disconnected" = "Disconnected ⚠";
          "format-alt" = "{ifname}: {ipaddr}/{cidr}";
          "on-click" = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
          "on-click-right" = "${pkgs.alacritty}/bin/alacritty -e nmtui";
        };

        battery = {
          states = {
            good = 95;
            warning = 30;
            critical = 15;
          };
          format = "{capacity}% {icon} {power}W";
          "format-charging" = "{capacity}%  {power}W";
          "format-plugged" = "{capacity}%  {power}W";
          "format-alt" = "{time} {icon}";
          "format-icons" = [
            ""
            ""
            ""
            ""
            ""
          ];
        };

        tray = {
          "icon-size" = 21;
          spacing = 10;
        };
      };
    };

    style = ''
      /* OLED High Contrast Waybar Style (Home Manager Managed) */
      * {
          border: none;
          border-radius: 0;
          font-family: "JetBrainsMono Nerd Font", "DejaVu Sans Mono", monospace;
          font-size: 14px;
          font-weight: bold;
      }

      window#waybar {
          background-color: #000000;
          color: #FFFFFF;
          border-bottom: 2px solid #333333;
          transition-property: background-color;
          transition-duration: .5s;
      }

      /* Modules - Restore original padding/margin */
      #clock,
      #battery,
      #cpu,
      #memory,
      #disk,
      #network,
      #pulseaudio,
      #tray,
      #custom-kanshi,
      #custom-system-stats,
      #mode {
          padding: 0 12px;
          margin: 0;
          color: #FFFFFF;
          background-color: #000000;
      }

      #workspaces button {
          padding: 0 8px;
          background-color: #000000;
          color: #888888;
          border-bottom: 3px solid transparent;
      }

      #workspaces button:hover {
          background: #1a1a1a;
          box-shadow: inherit;
          border-bottom: 3px solid #FFFFFF;
      }

      #workspaces button.focused {
          color: #00AAAA;
          border-bottom: 3px solid #00AAAA;
      }

      #workspaces button.urgent {
          background-color: #AA00AA;
          color: #FFFFFF;
      }

      /* Module Specific Colors - Vibrant but Balanced Palette */
      #custom-kanshi { color: #AA00AA; border-bottom: 3px solid #AA00AA; }
      #custom-system-stats { color: #00AA00; border-bottom: 3px solid #00AA00; }
      #clock { color: #00AAAA; border-bottom: 3px solid #00AAAA; }
      #memory { color: #AF0087; border-bottom: 3px solid #AF0087; }
      #disk { color: #AF8700; border-bottom: 3px solid #AF8700; }
      #pulseaudio { color: #8787D7; border-bottom: 3px solid #8787D7; }

      #pulseaudio.muted { color: #666666; border-bottom-color: #666666; }
      #pulseaudio.microphone { color: #D78700; border-bottom: 3px solid #D78700; }
      #pulseaudio.microphone.source-muted { color: #666666; border-bottom-color: #666666; }

      #network { color: #0087AF; border-bottom: 3px solid #0087AF; }
      #network.disconnected { color: #AA0000; border-bottom-color: #AA0000; }

      #battery { border-bottom: 3px solid #FFFFFF; }
      #battery.charging { color: #00AA00; border-bottom-color: #00AA00; }
      #battery.warning:not(.charging) { color: #AAAA00; border-bottom-color: #AAAA00; }
      #battery.critical:not(.charging) {
          color: #AA0000;
          border-bottom-color: #AA0000;
          animation-name: blink;
          animation-duration: 0.5s;
          animation-timing-function: linear;
          animation-iteration-count: infinite;
          animation-direction: alternate;
      }

      @keyframes blink {
          to { background-color: #AA0000; color: #000000; }
      }

      @import "/tmp/waybar-style-alert.css";
    '';
  };

  # Ensure the waybar service has the correct PATH for its custom scripts
  systemd.user.services.waybar.Service.ExecStartPre =
    "${pkgs.coreutils}/bin/touch /tmp/waybar-style-alert.css";
  systemd.user.services.waybar.Service.Environment = lib.mkForce "PATH=${
    lib.makeBinPath [
      pkgs.wofi
      pkgs.pulseaudio
      pkgs.procps
      pkgs.coreutils
      pkgs.networkmanagerapplet
      pkgs.alacritty
    ]
  }:/run/current-system/sw/bin";
}
