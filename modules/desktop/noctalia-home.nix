_: {
  flake.modules.homeManager.desktop-noctalia-home =
    { inputs, ... }:
    {
      imports = [
        inputs.noctalia.homeModules.default
      ];

      # Compositor-agnostic Noctalia v5 shell configuration.
      # Provides: bar, launcher, notifications, wallpaper, polkit, OSD,
      # screenshots, session actions.
      #
      # Startup is handled by the compositor's own module (exec-once for
      # Hyprland, spawn-at-startup for niri). This module only configures
      # the shell itself.
      programs.noctalia = {
        enable = true;

        # https://docs.noctalia.dev/v5/theming/#custom_palette
        # Installed to ~/.config/noctalia/palettes/ayu-blue.json by the HM module.
        customPalettes."ayu-blue" = {
          dark = {
            mPrimary = "#39BAE6";
            mOnPrimary = "#0B0E14";
            mSecondary = "#AAD94C";
            mOnSecondary = "#0B0E14";
            mTertiary = "#E6B450";
            mOnTertiary = "#0B0E14";
            mError = "#D95757";
            mOnError = "#0B0E14";
            mSurface = "#0B0E14";
            mOnSurface = "#D1D1C7";
            mSurfaceVariant = "#1E222A";
            mOnSurfaceVariant = "#8E959E";
            mOutline = "#565B66";
            mShadow = "#000000";
            mHover = "#39BAE6";
            mOnHover = "#0B0E14";
            terminal = {
              normal = {
                black = "#171B24";
                red = "#ED8274";
                green = "#87D96C";
                yellow = "#6DCBFA";
                blue = "#FACC6E";
                magenta = "#DABAFA";
                cyan = "#90E1C6";
                white = "#C7C7C7";
              };
              bright = {
                black = "#686868";
                red = "#F28779";
                green = "#D5FF80";
                yellow = "#73D0FF";
                blue = "#FFD173";
                magenta = "#DFBFFF";
                cyan = "#95E6CB";
                white = "#FFFFFF";
              };
              foreground = "#D1D1C7";
              background = "#1F2430";
              selectionFg = "#1F2430";
              selectionBg = "#409FFF";
              cursorText = "#1F2430";
              cursor = "#FFCC66";
            };
          };
          light = {
            mPrimary = "#55B4D4";
            mOnPrimary = "#F8F9FA";
            mSecondary = "#86B300";
            mOnSecondary = "#F8F9FA";
            mTertiary = "#FF8F40";
            mOnTertiary = "#F8F9FA";
            mError = "#E65050";
            mOnError = "#F8F9FA";
            mSurface = "#F8F9FA";
            mOnSurface = "#42474C";
            mSurfaceVariant = "#E4E6E9";
            mOnSurfaceVariant = "#6E757C";
            mOutline = "#8A9199";
            mShadow = "#F8F9FA";
            mHover = "#55B4D4";
            mOnHover = "#F8F9FA";
            terminal = {
              normal = {
                black = "#000000";
                red = "#EA6C6D";
                green = "#6CBF43";
                yellow = "#3199E1";
                blue = "#ECA944";
                magenta = "#9E75C7";
                cyan = "#46BA94";
                white = "#BABABA";
              };
              bright = {
                black = "#686868";
                red = "#F07171";
                green = "#86B300";
                yellow = "#399EE6";
                blue = "#F2AE49";
                magenta = "#A37ACC";
                cyan = "#4CBF99";
                white = "#D1D1D1";
              };
              foreground = "#42474C";
              background = "#F8F9FA";
              selectionFg = "#F8F9FA";
              selectionBg = "#035BD6";
              cursorText = "#F8F9FA";
              cursor = "#FFAA33";
            };
          };
        };

        settings = {
          # https://docs.noctalia.dev/v5/theming/
          theme = {
            mode = "dark";
            source = "custom";
            custom_palette = "ayu-blue";
            pure_black_dark = true;
          };

          # https://docs.noctalia.dev/v5/shell/
          shell = {
            telemetry_enabled = false;
            # Disable niri-specific overview launcher integration on all compositors.
            niri_overview_type_to_launch_enabled = false;
            # Noctalia's built-in polkit agent handles authentication dialogs.
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
          # Pairs with the compositor's layer/layerrule for noctalia-backdrop.
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
}
