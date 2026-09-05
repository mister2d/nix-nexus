# Merged into: flake.modules.homeManager.desktop-noctalia-home
# Configures: the compositor-agnostic noctalia v5 shell, bar, and wallpaper.
# Imported by: hosts/sweet16/home.nix (sweet16-home), hosts/petunia/home.nix (petunia-home).
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

        settings = {
          # https://docs.noctalia.dev/v5/theming/
          theme = {
            mode = "dark";
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
          # wallpaper.directory is left unset here. The active theme's default
          # (desktop-theme-home, modules/desktop/theme-wallpapers-home.nix)
          # supplies it via mkDefault. Runtime picks persist separately
          # to settings.toml and win over both.
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
