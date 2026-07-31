_: {
  flake.modules.homeManager.desktop-hyprland-home =
    {
      pkgs,
      lib,
      inputs,
      ...
    }:
    let
      mod = "SUPER";

      # Noctalia IPC helper — produces the exec string for Hyprland bind directives.
      # Hyprland's exec takes a plain string; niri's spawn takes listOf str.
      noc = cmd: "noctalia msg ${cmd}";

      accentHex = "39BAE6";
      inactiveHex = "333333";
      urgentHex = "AA00AA";
      bgHex = "000000";
      fgHex = "FFFFFF";

      # Workspace switch + move binds for 1–10, generated to avoid repetition.
      # Workspace 10 uses key "0", matching sway's $mod+0 = workspace 10.
      wsBinds = builtins.concatLists (
        builtins.genList (
          i:
          let
            num = i + 1;
            key = if num == 10 then "0" else toString num;
          in
          [
            "${mod}, ${key}, workspace, ${toString num}"
            "${mod} SHIFT, ${key}, movetoworkspace, ${toString num}"
          ]
        ) 10
      );
      # Vivaldi from unstable, paired with the codecs build that exports
      # av_dynamic_hdr_smpte2094_app5_to_t35
      vivaldi =
        (import inputs.nixpkgs-unstable {
          inherit (pkgs.stdenv.hostPlatform) system;
          config.allowUnfree = true;
        }).vivaldi.override
          {
            proprietaryCodecs = true;
            inherit
              (import inputs.pkgs-vivaldi-codecs {
                inherit (pkgs.stdenv.hostPlatform) system;
                config.allowUnfree = true;
              })
              vivaldi-ffmpeg-codecs
              ;
          };
    in
    {
      imports = [
        # Sets wayland.windowManager.hyprland.package to upstream v0.55.3.
        inputs.hyprland.homeManagerModules.default
      ];

      # -----------------------------------------------------------------------
      # Hyprland compositor
      # -----------------------------------------------------------------------
      wayland.windowManager.hyprland = {
        enable = true;
        xwayland.enable = true;
        configType = "hyprlang";

        systemd = {
          enable = true;
          variables = [
            "WAYLAND_DISPLAY"
            "HYPRLAND_INSTANCE_SIGNATURE"
            "XDG_CURRENT_DESKTOP"
            "XDG_SESSION_TYPE"
            "XDG_SESSION_DESKTOP"
          ];
          # Restart the portal once the environment is propagated; Noctalia
          # needs a fresh portal instance to register its screenshot backend.
          extraCommands = [
            "systemctl --user restart xdg-desktop-portal.service"
          ];
        };

        settings = {
          # ── Variables ─────────────────────────────────────────────────────
          "$mod" = mod;
          "$terminal" = "${pkgs.kitty}/bin/kitty";
          "$terminal2" = "${pkgs.ghostty}/bin/ghostty";

          # ── Environment variables ──────────────────────────────────────────
          env = [
            "GDK_BACKEND,wayland"
            "QT_QPA_PLATFORM,wayland;xcb"
            "QT_QPA_PLATFORMTHEME,"
            "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
            "ELECTRON_OZONE_PLATFORM_HINT,wayland"
            "NIXOS_OZONE_WL,1"
            "MOZ_ENABLE_WAYLAND,1"
            "SDL_VIDEODRIVER,wayland"
            "XDG_CURRENT_DESKTOP,Hyprland"
            "XDG_SESSION_TYPE,wayland"
            "XDG_SESSION_DESKTOP,Hyprland"
          ];

          # ── Startup ───────────────────────────────────────────────────────
          # HM's systemd integration injects dbus-update-activation-environment
          # and portal restart as exec-once entries before these. The Wayland
          # environment is ready before any exec-once entry runs.
          exec-once = [
            # Noctalia: bar, launcher, notifications, wallpaper, polkit, OSD.
            "noctalia"
            # Network manager tray (Noctalia's tray widget hosts it).
            "nm-applet --indicator"
            # Clipboard history.
            "${pkgs.wl-clipboard}/bin/wl-paste -t text --watch ${pkgs.clipman}/bin/clipman store --no-persist"
            # Battery alert script.
            "${(import ../../lib/custom-scripts.nix { inherit pkgs; }).battery-alert}/bin/battery-alert"
            # EasyEffects: two races to win —
            # 1. WAYLAND_DISPLAY is not in the systemd env until exec-once runs,
            #    so the service crashes on first start; reset-failed clears that.
            # 2. Noctalia's StatusNotifierWatcher may not be on the session bus
            #    yet; poll until it is before restarting so the tray icon lands.
            "bash -c 'until busctl --user status org.kde.StatusNotifierWatcher &>/dev/null; do sleep 0.2; done; systemctl --user reset-failed easyeffects.service; systemctl --user start easyeffects.service'"
          ];

          # ── General ───────────────────────────────────────────────────────
          general = {
            gaps_in = 5;
            gaps_out = 10;
            border_size = 2;
            "col.active_border" = "rgba(${accentHex}ee)";
            "col.inactive_border" = "rgba(${inactiveHex}aa)";
            resize_on_border = true;
            allow_tearing = false;
            layout = "dwindle";
          };

          # ── Decoration ────────────────────────────────────────────────────
          decoration = {
            rounding = 10;
            active_opacity = 1.0;
            inactive_opacity = 0.92;
            fullscreen_opacity = 1.0;

            blur = {
              enabled = false;
              size = 8;
              passes = 3;
              new_optimizations = true;
              xray = false;
              ignore_opacity = true;
              vibrancy = 0.15;
              vibrancy_darkness = 0.5;
            };

            shadow = {
              enabled = false;
              range = 8;
              render_power = 3;
              color = "rgba(00000066)";
              color_inactive = "rgba(00000033)";
            };

            dim_inactive = true;
            dim_strength = 0.1;
          };

          # ── Animations ────────────────────────────────────────────────────
          animations = {
            enabled = true;
            bezier = [
              "myBezier, 0.05, 0.9, 0.1, 1.05"
              "linear, 0.0, 0.0, 1.0, 1.0"
              "easeOut, 0.0, 0.0, 0.2, 1.0"
            ];
            animation = [
              "windows, 1, 4, myBezier"
              "windowsOut, 1, 4, default, popin 80%"
              "border, 1, 6, default"
              "borderangle, 1, 8, linear, loop"
              "fade, 1, 4, default"
              "workspaces, 1, 4, easeOut, slide"
              "layers, 1, 3, easeOut, slide"
            ];
          };

          # ── Input ─────────────────────────────────────────────────────────
          input = {
            kb_layout = "us";
            repeat_delay = 300;
            repeat_rate = 20;
            touchpad = {
              natural_scroll = true;
              tap-to-click = true;
              tap-and-drag = true;
              drag_lock = false;
              disable_while_typing = true;
              middle_button_emulation = true;
              clickfinger_behavior = true;
              scroll_factor = 1.0;
            };
            follow_mouse = 1;
            sensitivity = 0.0;
            accel_profile = "adaptive";
          };

          # ── Gestures ──────────────────────────────────────────────────────
          gestures = {
            workspace_swipe_invert = true;
            workspace_swipe_min_speed_to_force = 30;
          };

          # ── Layout ────────────────────────────────────────────────────────
          dwindle = {
            preserve_split = true;
          };
          master.new_status = "master";

          # ── Misc ──────────────────────────────────────────────────────────
          misc = {
            force_default_wallpaper = 0;
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
            mouse_move_enables_dpms = true;
            key_press_enables_dpms = true;
            enable_swallow = true;
            swallow_regex = "^(kitty|ghostty)$";
          };

          # ── Render / Color Management / HDR ───────────────────────────────
          # INTENTIONALLY ABSENT HERE. These are display-hardware-specific
          # (OLED HDR capability) and live in hardware-z16-hypr-home.nix.

          # ── Layer rules for Noctalia surfaces ─────────────────────────────
          # Noctalia publishes named wlr-layer-shell surfaces. These rules apply
          # blur and transparency effects via Hyprland's compositor pipeline.
          # ignorezero: prevents input bleed-through behind transparent regions.
          layerrule = [
            "blur on, match:namespace ^noctalia-backdrop$"
            "ignore_alpha 0.0, match:namespace ^noctalia-backdrop$"
            "blur on, match:namespace ^noctalia-bar-main$"
            "ignore_alpha 0.0, match:namespace ^noctalia-bar-main$"
            "blur on, match:namespace ^noctalia-notification$"
            "ignore_alpha 0.0, match:namespace ^noctalia-notification$"
            "blur on, match:namespace ^noctalia-panel$"
            "ignore_alpha 0.0, match:namespace ^noctalia-panel$"
          ];

          # ── Window rules ──────────────────────────────────────────────────
          windowrule = [
            "float on, match:class ^(.*)$, match:title ^(Open File|Open Folder|Save File|Save As)$"
            "float on, match:class ^(pavucontrol)$"
            "float on, match:class ^(nm-connection-editor)$"
            "float on, match:class ^(wdisplays)$"
            "immediate on, match:fullscreen 1"
            "immediate on, match:class ^(steam_app_).*$"
            "float on, match:class ^(steam)$, match:title ^(Steam)$"
            "size 850 640, match:class ^(steam)$, match:title ^(Steam)$"
            "float on, match:class ^(steam)$, match:title ^(Friends List)$"
            "size 300 650, match:class ^(steam)$, match:title ^(Friends List)$"
          ];

          # ── Keybindings ───────────────────────────────────────────────────
          # Noctalia owns: panels, volume, brightness, screenshots, session.
          bind = [
            # ── Noctalia panels ──
            "$mod, D, exec, ${noc "panel-toggle launcher"}"
            "$mod, S, exec, ${noc "panel-toggle control-center"}"
            "$mod, COMMA, exec, ${noc "settings-toggle"}"
            "$mod, Escape, exec, ${noc "panel-toggle session"}"
            "$mod SHIFT, L, exec, ${noc "session lock"}"

            # ── Applications ──
            "$mod, RETURN, exec, $terminal"
            "$mod SHIFT, RETURN, exec, $terminal2"
            "$mod SHIFT, B, exec, ${pkgs.bash}/bin/bash -c 'if command -v gpu-launch >/dev/null; then exec gpu-launch google-chrome-stable --ozone-platform=wayland --disable-features=ExtensionManifestV2Unsupported; else exec google-chrome-stable --ozone-platform=wayland --disable-features=ExtensionManifestV2Unsupported; fi'"
            "$mod CTRL, B, exec, google-chrome-stable --ozone-platform=wayland"
            "$mod SHIFT, D, exec, ${pkgs.wdisplays}/bin/wdisplays"
            "$mod SHIFT, A, exec, audio-selector sink"
            "$mod SHIFT, M, exec, audio-selector source"
            "$mod ALT, E, exec, ${pkgs.bash}/bin/bash -c 'BEMOJI_PICKER_CMD=\"${pkgs.fuzzel}/bin/fuzzel --dmenu --width 40 --lines 10\" ${pkgs.bemoji}/bin/bemoji -n -c'"
            "$mod SHIFT, V, exec, ${vivaldi}/bin/vivaldi --ozone-platform=wayland --disable-features=ExtensionManifestV2Unsupported"

            # ── Window management ──
            "$mod, Q, killactive"
            "$mod SHIFT, E, exit"
            "$mod, F, fullscreen"
            "$mod SHIFT, SPACE, togglefloating"
            "$mod, P, pseudo"
            "$mod, E, layoutmsg, togglesplit"
            "$mod, R, submap, resize"

            # ── Focus — Vim keys ──
            "$mod, h, movefocus, l"
            "$mod, j, movefocus, d"
            "$mod, k, movefocus, u"
            "$mod, l, movefocus, r"

            # ── Focus — Arrow keys ──
            "$mod, left, movefocus, l"
            "$mod, down, movefocus, d"
            "$mod, up, movefocus, u"
            "$mod, right, movefocus, r"

            # ── Move — Vim keys ──
            "$mod SHIFT, h, movewindow, l"
            "$mod SHIFT, j, movewindow, d"
            "$mod SHIFT, k, movewindow, u"
            "$mod SHIFT, l, movewindow, r"

            # ── Move — Arrow keys ──
            "$mod SHIFT, left, movewindow, l"
            "$mod SHIFT, down, movewindow, d"
            "$mod SHIFT, up, movewindow, u"
            "$mod SHIFT, right, movewindow, r"

            # ── Screenshots — Noctalia handles capture and clipboard ──
            ", Print, exec, ${noc "screenshot-region"}"
            "SHIFT, Print, exec, ${noc "screenshot-fullscreen"}"
          ]
          ++ wsBinds;

          # Mouse binds
          bindm = [
            "$mod, mouse:272, movewindow"
            "$mod, mouse:273, resizewindow"
          ];

          # Repeat binds — Noctalia owns volume and brightness OSD
          binde = [
            ", XF86AudioRaiseVolume, exec, ${noc "volume-up"}"
            ", XF86AudioLowerVolume, exec, ${noc "volume-down"}"
            ", XF86MonBrightnessUp, exec, ${noc "brightness-up"}"
            ", XF86MonBrightnessDown, exec, ${noc "brightness-down"}"
          ];

          # Locked binds (active on lockscreen)
          bindl = [
            # Noctalia owns mute OSD
            ", XF86AudioMute, exec, ${noc "volume-mute"}"
            # Mic mute: no Noctalia IPC; pamixer handles this directly.
            ", XF86AudioMicMute, exec, ${pkgs.pamixer}/bin/pamixer --default-source -t"
          ];
        };

        # Resize submap (raw hyprlang; cleaner than settings.submaps for this).
        extraConfig = ''
          submap = resize
          binde = , right,  resizeactive, 20 0
          binde = , left,   resizeactive, -20 0
          binde = , up,     resizeactive, 0 -20
          binde = , down,   resizeactive, 0 20
          binde = , l,      resizeactive, 20 0
          binde = , h,      resizeactive, -20 0
          binde = , k,      resizeactive, 0 -20
          binde = , j,      resizeactive, 0 20
          bind  = , escape, submap, reset
          bind  = , return, submap, reset
          bind  = $mod, R,  submap, reset
          submap = reset
        '';
      };

      # -----------------------------------------------------------------------
      # Hyprlock — GPU-accelerated lock screen
      # Requires security.pam.services.hyprlock = {} in desktop-hyprland.nix.
      # Invoked by hypridle on idle timeout and by loginctl lock-session.
      # -----------------------------------------------------------------------
      programs.hyprlock = {
        enable = true;
        settings = {
          general = {
            disable_loading_bar = false;
            hide_cursor = true;
            grace = 0;
            no_fade_in = false;
          };
          background = [
            {
              monitor = "";
              color = "rgba(0, 0, 0, 1.0)";
              blur_passes = 3;
              blur_size = 8;
              brightness = 0.5;
            }
          ];
          input-field = [
            {
              monitor = "";
              size = "300, 50";
              outline_thickness = 2;
              dots_size = 0.2;
              dots_spacing = 0.15;
              dots_center = true;
              "col.outer_color" = "rgba(${accentHex}ff)";
              "col.inner_color" = "rgba(${bgHex}ff)";
              "col.font_color" = "rgba(${fgHex}ff)";
              "col.fail_color" = "rgba(${urgentHex}ff)";
              "col.check_color" = "rgba(${accentHex}88)";
              placeholder_text = "<i>Password</i>";
              fail_text = "<b>$FAIL ($ATTEMPTS)</b>";
              fail_transition = 300;
              rounding = 5;
              position = "0, -80";
              halign = "center";
              valign = "center";
            }
          ];
          label = [
            {
              monitor = "";
              text = "cmd[update:1000] date +'%H:%M:%S'";
              "color" = "rgba(${fgHex}cc)";
              font_size = 48;
              font_family = "JetBrainsMono Nerd Font";
              position = "0, 80";
              halign = "center";
              valign = "center";
            }
            {
              monitor = "";
              text = "cmd[update:60000] date +'%A, %B %d %Y'";
              "color" = "rgba(${fgHex}88)";
              font_size = 18;
              font_family = "JetBrainsMono Nerd Font";
              position = "0, 160";
              halign = "center";
              valign = "center";
            }
          ];
        };
      };

      # -----------------------------------------------------------------------
      # Hypridle — idle and power management daemon
      # -----------------------------------------------------------------------
      services.hypridle = {
        enable = true;
        settings = {
          general = {
            lock_cmd = "pidof hyprlock || hyprlock";
            before_sleep_cmd = "loginctl lock-session";
            after_sleep_cmd = "hyprctl dispatch dpms on";
          };
          listener = [
            {
              timeout = 600;
              on-timeout = "loginctl lock-session";
            }
            {
              timeout = 900;
              on-timeout = "hyprctl dispatch dpms off";
              on-resume = "hyprctl dispatch dpms on";
            }
          ];
        };
      };

      # -----------------------------------------------------------------------
      # Hyprsunset — blue-light filter
      # Noctalia does not bundle a blue-light daemon. Runs as an independent
      # systemd user service tied to hyprland-session.target.
      # -----------------------------------------------------------------------
      services.hyprsunset = {
        enable = true;
        extraArgs = [
          "--temperature"
          "4000"
        ];
      };

      home.sessionVariables = {
        XDG_CURRENT_DESKTOP = lib.mkDefault "Hyprland";
        XDG_SESSION_TYPE = lib.mkDefault "wayland";
        XDG_SESSION_DESKTOP = lib.mkDefault "Hyprland";
      };

      home.packages = with pkgs; [
        hyprpicker
        wdisplays
      ];
    };
}
