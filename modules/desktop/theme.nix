_: {
  flake.modules.nixos.desktop-default =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      themes = import ../../lib/themes { inherit pkgs; };
      cfg = config.nix-nexus.theme;
      theme = themes.${cfg.name};
    in
    {
      options.nix-nexus.theme = {
        name = lib.mkOption {
          type = lib.types.enum (builtins.attrNames themes);
          default = "ayu-dark";
          description = "Named desktop theme from lib/themes.";
        };
        accent = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Host-level base0D accent override (bare hex, no '#') applied on top of the theme's own overrides.";
        };
        wallpapers.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Install the selected theme's wallpaper pack (when it has one) and point noctalia's default wallpaper directory at it.";
        };
      };

      config = {
        stylix = {
          enable = true;
          # Permanent policy: opt-in per target.
          autoEnable = false;
          # Keeps the Rust palette generator out of the closure entirely, and
          # keeps noctalia (not hyprpaper) the wallpaper owner.
          image = null;
          inherit (theme) polarity;
          base16Scheme = theme.scheme;
          override = theme.override // lib.optionalAttrs (cfg.accent != null) { base0D = cfg.accent; };
          fonts = {
            monospace = {
              package = pkgs.nerd-fonts.jetbrains-mono;
              name = "JetBrainsMono Nerd Font";
            };
            sansSerif = {
              package = pkgs.noto-fonts;
              name = "Noto Sans";
            };
            serif = {
              package = pkgs.noto-fonts;
              name = "Noto Serif";
            };
            emoji = {
              package = pkgs.noto-fonts-color-emoji;
              name = "Noto Color Emoji";
            };
            sizes = {
              terminal = 14;
              applications = 12;
              desktop = 10;
              popups = 10;
            };
          };
          cursor = {
            package = pkgs.adwaita-icon-theme;
            name = "Adwaita";
            size = 24;
          };
        };
      };
    };
}
