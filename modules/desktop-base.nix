{ ... }:
{
  # ============================================================================
  # Desktop Base Aspect: Essential UI Infrastructure
  # ============================================================================

  den.aspects.desktop-base-aspect = {
    nixos = { config, pkgs, lib, ... }: {
      # Fonts
      fonts.packages = with pkgs; [ noto-fonts noto-fonts-cjk-sans noto-fonts-color-emoji liberation_ttf fira-code fira-code-symbols mplus-outline-fonts.githubRelease dina-font proggyfonts nerd-fonts.jetbrains-mono nerd-fonts.fira-code nerd-fonts.symbols-only ];

      # Greetd
      services.greetd = {
        enable = true;
        settings.default_session = {
          command = lib.mkDefault "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks";
          user = "greeter";
        };
      };

      environment.systemPackages = with pkgs; [ tuigreet ];
      environment.sessionVariables = { NIXOS_OZONE_WL = "1"; };

      xdg.portal = {
        enable = true;
        wlr.enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-gnome ];
        config = lib.mkForce {
          common.default = [ "gtk" "gnome" ];
          sway = {
            default = [ "wlr" "gtk" "gnome" ];
            "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
            "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
          };
          niri.default = [ "gnome" "gtk" ];
        };
      };

      # Home Manager Configuration for ddukes
      home-manager.users.ddukes = { config, ... }:
        let
          swayEnabled = config.wayland.windowManager.sway.enable or false;
        in {
          # Notifications (Dunst)
          services.dunst = {
            enable = true;
            settings = {
              global = {
                width = 300; height = 300; offset = "30x30"; origin = "top-right";
                padding = 16; horizontal_padding = 16; frame_width = 2; frame_color = "#00AAAA";
                font = "JetBrainsMono Nerd Font 10"; line_height = 4; alignment = "left";
                word_wrap = "yes"; icon_position = "left"; max_icon_size = 32;
                browser = "${pkgs.google-chrome}/bin/google-chrome-stable";
                title = "Dunst"; class = "Dunst";
              };
              urgency_low = { background = "#000000"; foreground = "#FFFFFF"; timeout = 10; };
              urgency_normal = { background = "#000000"; foreground = "#FFFFFF"; timeout = 10; };
              urgency_critical = { background = "#000000"; foreground = "#FFFFFF"; frame_color = "#AA00AA"; timeout = 0; };
            };
          };

          systemd.user.services.dunst.Unit.PartOf = lib.mkForce [ "graphical-session.target" ];
          systemd.user.services.dunst.Install.WantedBy = lib.mkForce [ "graphical-session.target" ];

          # Waybar (conditionally for Sway)
          programs.waybar = let
            scripts = import ./_programs/_custom-scripts.nix { inherit pkgs; };
          in lib.mkIf swayEnabled {
            enable = true;
            systemd.enable = true;
            systemd.target = "sway-session.target";
            settings.mainBar = {
              layer = "top"; position = "top"; height = 32; spacing = 4;
              output = [ "eDP-1" "DP-1" "DP-2" "DP-3" "DP-4" ];
              modules-left = [ "sway/workspaces" "sway/mode" "sway/window" ];
              modules-center = [ "custom/kanshi" "clock" ];
              modules-right = [ "custom/system-stats" "memory" "disk" "pulseaudio" "pulseaudio#microphone" "network" "battery" "tray" ];
              "sway/workspaces" = { disable-scroll = true; all-outputs = true; format = "{name}"; };
              "custom/kanshi" = { format = " {}"; exec = "${pkgs.coreutils}/bin/cat /tmp/kanshi-profile 2>/dev/null || echo 'default'"; interval = "once"; signal = 8; tooltip = true; };
              clock = { format = "{:%Y-%m-%d %H:%M:%S}"; interval = 1; };
              "custom/system-stats" = { exec = "${scripts.system-stats}/bin/system-stats"; return-type = "json"; interval = 2; format = "{}"; };
              memory = { format = "{used:0.1f}G/{total:0.1f}G "; };
              pulseaudio = { format = "{volume}% {icon}"; on-click = "${pkgs.pamixer}/bin/pamixer -t"; "format-icons" = { default = [ "" "" "" ]; }; };
              battery = { states = { warning = 30; critical = 15; }; format = "{capacity}% {icon} {power}W"; "format-icons" = [ "" "" "" "" "" ]; };
            };
            style = ''* { border: none; border-radius: 0; font-family: "JetBrainsMono Nerd Font"; font-size: 14px; font-weight: bold; } window#waybar { background-color: #000000; color: #FFFFFF; border-bottom: 2px solid #333333; } #clock, #battery, #memory, #disk, #network, #pulseaudio, #tray { padding: 0 12px; } @import "/tmp/waybar-style-alert.css"; '';
          };

          systemd.user.services.waybar = lib.mkIf swayEnabled {
            Unit = {
              ConditionEnvironment = lib.mkForce "XDG_CURRENT_DESKTOP=sway";
              PartOf = [ "graphical-session.target" ];
              After = [ "pipewire.service" "wireplumber.service" "pipewire-pulse.service" ];
            };
            Service = {
              ExecStartPre = "${pkgs.coreutils}/bin/touch /tmp/waybar-style-alert.css";
              Environment = lib.mkForce "PATH=${lib.makeBinPath [ pkgs.wofi pkgs.pulseaudio pkgs.procps pkgs.coreutils pkgs.networkmanagerapplet pkgs.kitty ]}:/run/current-system/sw/bin";
            };
          };
        };
    };
  };
}
