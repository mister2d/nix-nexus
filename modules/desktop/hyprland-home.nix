# Registry key: flake.modules.homeManager.desktop-hyprland-home
# Configures: Hyprland keybindings, workspace binds, startup commands (Lua config), and the xdg-terminal-exec terminal preference list.
# Imported by: hosts/sweet16/home.nix (sweet16-home), hosts/petunia/home.nix (petunia-home).
_: {
  flake.modules.homeManager.desktop-hyprland-home =
    {
      pkgs,
      lib,
      inputs,
      config,
      ...
    }:
    let
      pin = import ../../lib/pinned-pkgs.nix { inherit pkgs; };
      customScripts = import ../../lib/custom-scripts.nix { inherit pkgs; };

      mod = "SUPER";

      luaStr = lib.generators.toLua { };
      inherit (lib.generators) mkLuaInline;

      # Noctalia IPC helper — produces the command string for hl.dsp.exec_cmd.
      noc = cmd: "noctalia msg ${cmd}";

      inherit (config.lib.stylix.colors) base05;

      # hl.bind(keys, dispatcher, opts). `dsp` is a Lua expression.
      mkBindRaw = keys: dsp: opts: {
        _args = [
          keys
          (mkLuaInline dsp)
        ]
        ++ lib.optional (opts != { }) opts;
      };
      # Bind with the main modifier.
      mkBind = keys: mkBindRaw "${mod} + ${keys}";

      exec = cmd: "hl.dsp.exec_cmd(${luaStr cmd})";

      # Workspace switch + move binds for 1–10, generated to avoid repetition.
      # Workspace 10 uses key "0", matching sway's $mod+0 = workspace 10.
      wsBinds = lib.concatLists (
        lib.genList (
          i:
          let
            num = toString (i + 1);
            key = if i == 9 then "0" else num;
          in
          [
            (mkBind key "hl.dsp.focus({ workspace = ${num} })" { })
            (mkBind "SHIFT + ${key}" "hl.dsp.window.move({ workspace = ${num} })" { })
          ]
        ) 10
      );

      # Vim keys and arrow keys, each mapped to a Hyprland direction.
      directions = {
        h = "left";
        j = "down";
        k = "up";
        l = "right";
        left = "left";
        down = "down";
        up = "up";
        right = "right";
      };
      focusBinds = lib.mapAttrsToList (
        key: dir: mkBind key "hl.dsp.focus({ direction = \"${dir}\" })" { }
      ) directions;
      moveBinds = lib.mapAttrsToList (
        key: dir: mkBind "SHIFT + ${key}" "hl.dsp.window.move({ direction = \"${dir}\" })" { }
      ) directions;

      mkEnv = name: value: {
        _args = [
          name
          value
        ];
      };

      startupCommands = [
        # Noctalia: bar, launcher, notifications, wallpaper, polkit, OSD.
        "noctalia"
        # Network manager tray (Noctalia's tray widget hosts it).
        "nm-applet --indicator"
        # Clipboard history.
        "${pkgs.wl-clipboard}/bin/wl-paste -t text --watch ${pkgs.clipman}/bin/clipman store --no-persist"
        # Battery alert script.
        "${customScripts.battery-alert}/bin/battery-alert"
        # EasyEffects: two races to win —
        # 1. WAYLAND_DISPLAY is not in the systemd env until the start hook runs,
        #    so the service crashes on first start. reset-failed clears that.
        # 2. Noctalia's StatusNotifierWatcher may not be on the session bus
        #    yet. Poll until it is before restarting so the tray icon lands.
        "bash -c 'until busctl --user status org.kde.StatusNotifierWatcher &>/dev/null; do sleep 0.2; done; systemctl --user reset-failed easyeffects.service; systemctl --user start easyeffects.service'"
      ];

      # Layer rule for a Noctalia surface: blur with transparent regions
      # ignored so input does not bleed through.
      noctaliaLayerRule = namespace: {
        match.namespace = "^noctalia-${namespace}$";
        blur = true;
        ignore_alpha = 0.0;
      };

      # Vivaldi from unstable with proprietary codecs
      vivaldi = (pin.pinned inputs.nixpkgs-unstable).vivaldi.override {
        proprietaryCodecs = true;
      };
    in
    {
      # -----------------------------------------------------------------------
      # Hyprland compositor
      # -----------------------------------------------------------------------
      wayland.windowManager.hyprland = {
        enable = true;
        # Matches programs.hyprland.package in desktop-hyprland.nix (NixOS).
        package = (pin.pinned inputs.nixpkgs-hyprland).hyprland;
        # The NixOS module (programs.hyprland.portalPackage) installs the one xdph.
        portalPackage = null;
        xwayland.enable = true;
        configType = "lua";

        systemd = {
          enable = true;
          # PATH is exported because xdph finds hyprctl on the inherited PATH.
          variables = [
            "PATH"
            "WAYLAND_DISPLAY"
            "HYPRLAND_INSTANCE_SIGNATURE"
            "XDG_CURRENT_DESKTOP"
            "XDG_SESSION_TYPE"
            "XDG_SESSION_DESKTOP"
          ];
          # Restart the portal once the environment is propagated. Noctalia
          # needs a fresh portal instance to register its screenshot backend.
          extraCommands = [
            "systemctl --user restart xdg-desktop-portal.service"
          ];
        };

        settings = {
          # ── Environment variables ──────────────────────────────────────────
          env = [
            (mkEnv "GDK_BACKEND" "wayland")
            (mkEnv "QT_QPA_PLATFORM" "wayland;xcb")
            (mkEnv "QT_WAYLAND_DISABLE_WINDOWDECORATION" "1")
            (mkEnv "ELECTRON_OZONE_PLATFORM_HINT" "wayland")
            (mkEnv "NIXOS_OZONE_WL" "1")
            (mkEnv "MOZ_ENABLE_WAYLAND" "1")
            (mkEnv "SDL_VIDEODRIVER" "wayland")
            (mkEnv "XDG_CURRENT_DESKTOP" "Hyprland")
            (mkEnv "XDG_SESSION_TYPE" "wayland")
            (mkEnv "XDG_SESSION_DESKTOP" "Hyprland")
          ];

          # ── Startup ───────────────────────────────────────────────────────
          # HM's systemd integration injects dbus-update-activation-environment
          # and portal restart in its own hyprland.start hook. The Wayland
          # environment is ready before any command here runs.
          on = {
            _args = [
              "hyprland.start"
              (mkLuaInline ''
                function()
                ${lib.concatMapStrings (cmd: "  hl.exec_cmd(${luaStr cmd})\n") startupCommands}end
              '')
            ];
          };

          config = {
            # ── General ─────────────────────────────────────────────────────
            general = {
              gaps_in = 5;
              gaps_out = 10;
              border_size = 2;
              resize_on_border = true;
              allow_tearing = false;
              layout = "dwindle";
            };

            # ── Decoration ──────────────────────────────────────────────────
            decoration = {
              rounding = 10;
              active_opacity = 1.0;
              inactive_opacity = 1.0;
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
                color_inactive = "rgba(00000033)";
              };

              dim_inactive = true;
              dim_strength = 0.1;
            };

            animations.enabled = true;

            # ── Input ───────────────────────────────────────────────────────
            input = {
              kb_layout = "us";
              repeat_delay = 300;
              repeat_rate = 20;
              touchpad = {
                natural_scroll = true;
                tap_to_click = true;
                tap_and_drag = true;
                drag_lock = false;
                disable_while_typing = true;
                middle_button_emulation = true;
                clickfinger_behavior = true;
                scroll_factor = 1.0;
              };
              follow_mouse = 1;
              sensitivity = 0.0;
              accel_profile = lib.mkDefault "adaptive";
            };

            # ── Gestures ────────────────────────────────────────────────────
            gestures = {
              workspace_swipe_invert = true;
              workspace_swipe_min_speed_to_force = 30;
            };

            # ── Layout ──────────────────────────────────────────────────────
            dwindle.preserve_split = true;
            master.new_status = "master";

            # ── Misc ────────────────────────────────────────────────────────
            misc = {
              force_default_wallpaper = 0;
              disable_hyprland_logo = true;
              disable_splash_rendering = true;
              mouse_move_enables_dpms = true;
              key_press_enables_dpms = true;
              enable_swallow = true;
              swallow_regex = "^(kitty|com\\.mitchellh\\.ghostty)$";
            };

            # ── Render / Color Management / HDR ─────────────────────────────
            # INTENTIONALLY ABSENT HERE. These are display-hardware-specific
            # (OLED HDR capability) and live in hardware-z16-hypr-home.nix.
          };

          # ── Animations ────────────────────────────────────────────────────
          curve = [
            {
              _args = [
                "myBezier"
                {
                  type = "bezier";
                  points = [
                    [
                      0.05
                      0.9
                    ]
                    [
                      0.1
                      1.05
                    ]
                  ];
                }
              ];
            }
            {
              _args = [
                "linear"
                {
                  type = "bezier";
                  points = [
                    [
                      0.0
                      0.0
                    ]
                    [
                      1.0
                      1.0
                    ]
                  ];
                }
              ];
            }
            {
              _args = [
                "easeOut"
                {
                  type = "bezier";
                  points = [
                    [
                      0.0
                      0.0
                    ]
                    [
                      0.2
                      1.0
                    ]
                  ];
                }
              ];
            }
          ];
          animation = [
            {
              leaf = "windows";
              enabled = true;
              speed = 4;
              bezier = "myBezier";
            }
            {
              leaf = "windowsOut";
              enabled = true;
              speed = 4;
              bezier = "default";
              style = "popin 80%";
            }
            {
              leaf = "border";
              enabled = true;
              speed = 6;
              bezier = "default";
            }
            {
              leaf = "borderangle";
              enabled = true;
              speed = 8;
              bezier = "linear";
              style = "loop";
            }
            {
              leaf = "fade";
              enabled = true;
              speed = 4;
              bezier = "default";
            }
            {
              leaf = "workspaces";
              enabled = true;
              speed = 4;
              bezier = "easeOut";
              style = "slide";
            }
            {
              leaf = "layers";
              enabled = true;
              speed = 3;
              bezier = "easeOut";
              style = "slide";
            }
          ];

          # ── Layer rules for Noctalia surfaces ─────────────────────────────
          # Noctalia publishes named wlr-layer-shell surfaces. These rules apply
          # blur and transparency effects via Hyprland's compositor pipeline.
          layer_rule = map noctaliaLayerRule [
            "backdrop"
            "bar-main"
            "notification"
            "panel"
          ];

          # ── Window rules ──────────────────────────────────────────────────
          window_rule = [
            # Clients such as kitty request maximize on start; Hyprland would
            # otherwise honor it and overlay siblings instead of tiling.
            {
              name = "suppress-maximize-events";
              match.class = ".*";
              suppress_event = "maximize";
            }
            {
              match = {
                class = "^(.*)$";
                title = "^(Open File|Open Folder|Save File|Save As)$";
              };
              float = true;
            }
            {
              match.class = "^(pavucontrol)$";
              float = true;
            }
            {
              match.class = "^(nm-connection-editor)$";
              float = true;
            }
            {
              match.class = "^(wdisplays)$";
              float = true;
            }
            {
              match.fullscreen = true;
              immediate = true;
            }
            {
              match.class = "^(steam_app_).*$";
              immediate = true;
            }
            {
              match = {
                class = "^(steam)$";
                title = "^(Steam)$";
              };
              float = true;
            }
            {
              match = {
                class = "^(steam)$";
                title = "^(Steam)$";
              };
              size = [
                850
                640
              ];
            }
            {
              match = {
                class = "^(steam)$";
                title = "^(Friends List)$";
              };
              float = true;
            }
            {
              match = {
                class = "^(steam)$";
                title = "^(Friends List)$";
              };
              size = [
                300
                650
              ];
            }
          ];

          # ── Keybindings ───────────────────────────────────────────────────
          # Noctalia owns: panels, volume, brightness, screenshots, session.
          bind = [
            # ── Noctalia panels ──
            (mkBind "D" (exec (noc "panel-toggle launcher")) { })
            (mkBind "S" (exec (noc "panel-toggle control-center")) { })
            (mkBind "COMMA" (exec (noc "settings-toggle")) { })
            (mkBind "Escape" (exec (noc "panel-toggle session")) { })
            (mkBind "SHIFT + L" (exec (noc "session lock")) { })

            # ── Applications ──
            (mkBind "RETURN" (exec "${lib.getExe config.xdg.terminal-exec.package}") { })
            (mkBind "SHIFT + RETURN" (exec "${pkgs.kitty}/bin/kitty") { })
            (mkBind "SHIFT + B"
              (exec "${pkgs.bash}/bin/bash -c 'if command -v gpu-launch >/dev/null; then exec gpu-launch google-chrome-stable --ozone-platform=wayland --disable-features=ExtensionManifestV2Unsupported; else exec google-chrome-stable --ozone-platform=wayland --disable-features=ExtensionManifestV2Unsupported; fi'")
              { }
            )
            (mkBind "CTRL + B" (exec "google-chrome-stable --ozone-platform=wayland") { })
            (mkBind "SHIFT + D" (exec "${pkgs.wdisplays}/bin/wdisplays") { })
            (mkBind "SHIFT + A" (exec "audio-selector sink") { })
            (mkBind "SHIFT + M" (exec "audio-selector source") { })
            (mkBind "ALT + E"
              (exec "${pkgs.bash}/bin/bash -c 'BEMOJI_PICKER_CMD=\"${pkgs.fuzzel}/bin/fuzzel --dmenu --width 40 --lines 10\" ${pkgs.bemoji}/bin/bemoji -n -c'")
              { }
            )
            (mkBind "SHIFT + V"
              (exec "${vivaldi}/bin/vivaldi --ozone-platform=wayland --disable-features=ExtensionManifestV2Unsupported")
              { }
            )

            # ── Window management ──
            (mkBind "Q" "hl.dsp.window.close()" { })
            (mkBind "SHIFT + E" "hl.dsp.exit()" { })
            (mkBind "F" "hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"toggle\" })" { })
            (mkBind "SHIFT + SPACE" "hl.dsp.window.float({ action = \"toggle\" })" { })
            (mkBind "P" "hl.dsp.window.pseudo()" { })
            (mkBind "E" "hl.dsp.layout(\"togglesplit\")" { })
            (mkBind "R" "hl.dsp.submap(\"resize\")" { })

            # ── Screenshots — Noctalia handles capture and clipboard ──
            (mkBindRaw "Print" (exec (noc "screenshot-region")) { })
            (mkBindRaw "SHIFT + Print" (exec (noc "screenshot-fullscreen")) { })
          ]
          # Focus and move — Vim keys and arrow keys.
          ++ focusBinds
          ++ moveBinds
          ++ wsBinds
          # Mouse binds
          ++ [
            (mkBind "mouse:272" "hl.dsp.window.drag()" { mouse = true; })
            (mkBind "mouse:273" "hl.dsp.window.resize()" { mouse = true; })
          ]
          # Repeat binds — Noctalia owns volume and brightness OSD
          ++ [
            (mkBindRaw "XF86AudioRaiseVolume" (exec (noc "volume-up")) { repeating = true; })
            (mkBindRaw "XF86AudioLowerVolume" (exec (noc "volume-down")) { repeating = true; })
            (mkBindRaw "XF86MonBrightnessUp" (exec (noc "brightness-up")) { repeating = true; })
            (mkBindRaw "XF86MonBrightnessDown" (exec (noc "brightness-down")) { repeating = true; })
          ]
          # Locked binds (active on lockscreen)
          ++ [
            # Noctalia owns mute OSD
            (mkBindRaw "XF86AudioMute" (exec (noc "volume-mute")) { locked = true; })
            # Mic mute: no Noctalia IPC. pamixer handles this directly.
            (mkBindRaw "XF86AudioMicMute" (exec "${pkgs.pamixer}/bin/pamixer --default-source -t") {
              locked = true;
            })
          ];
        };

        # ── Resize submap ───────────────────────────────────────────────────
        submaps.resize.settings.bind = [
          (mkBindRaw "right" "hl.dsp.window.resize({ x = 20, y = 0, relative = true })" {
            repeating = true;
          })
          (mkBindRaw "left" "hl.dsp.window.resize({ x = -20, y = 0, relative = true })" {
            repeating = true;
          })
          (mkBindRaw "up" "hl.dsp.window.resize({ x = 0, y = -20, relative = true })" {
            repeating = true;
          })
          (mkBindRaw "down" "hl.dsp.window.resize({ x = 0, y = 20, relative = true })" {
            repeating = true;
          })
          (mkBindRaw "l" "hl.dsp.window.resize({ x = 20, y = 0, relative = true })" { repeating = true; })
          (mkBindRaw "h" "hl.dsp.window.resize({ x = -20, y = 0, relative = true })" {
            repeating = true;
          })
          (mkBindRaw "k" "hl.dsp.window.resize({ x = 0, y = -20, relative = true })" {
            repeating = true;
          })
          (mkBindRaw "j" "hl.dsp.window.resize({ x = 0, y = 20, relative = true })" { repeating = true; })
          (mkBindRaw "escape" "hl.dsp.submap(\"reset\")" { })
          (mkBindRaw "return" "hl.dsp.submap(\"reset\")" { })
          (mkBind "R" "hl.dsp.submap(\"reset\")" { })
        ];
      };

      # -----------------------------------------------------------------------
      # Default terminal — xdg-terminal-exec
      # Ordered preference list that the keybind, launchers and Terminal=true
      # desktop entries all follow.
      # -----------------------------------------------------------------------
      xdg.terminal-exec = {
        enable = true;
        settings.default = [
          "com.mitchellh.ghostty.desktop"
          "kitty.desktop"
        ];
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
          background = {
            monitor = "";
            blur_passes = 3;
            blur_size = 8;
            brightness = 0.5;
          };
          input-field = {
            monitor = "";
            size = "300, 50";
            outline_thickness = 2;
            dots_size = 0.2;
            dots_spacing = 0.15;
            dots_center = true;
            placeholder_text = "<i>Password</i>";
            fail_text = "<b>$FAIL ($ATTEMPTS)</b>";
            fail_transition = 300;
            rounding = 5;
            position = "0, -80";
            halign = "center";
            valign = "center";
          };
          label = [
            {
              monitor = "";
              text = "cmd[update:1000] date +'%H:%M:%S'";
              "color" = "rgba(${base05}cc)";
              font_size = 48;
              font_family = config.stylix.fonts.monospace.name;
              position = "0, 80";
              halign = "center";
              valign = "center";
            }
            {
              monitor = "";
              text = "cmd[update:60000] date +'%A, %B %d %Y'";
              "color" = "rgba(${base05}88)";
              font_size = 18;
              font_family = config.stylix.fonts.monospace.name;
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
