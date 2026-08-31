# Installs the active theme's wallpaper pack (lib/themes/wallpapers.nix)
# into the user's home and points noctalia's default wallpaper directory at
# it. A no-op when the theme has no pack (cfg.wallpapers.enable and
# theme.wallpapers both gate this).
_: {
  flake.modules.homeManager.desktop-theme-home =
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      cfg = osConfig.nix-nexus.theme;
      theme = (import ../../lib/themes { inherit pkgs; }).${cfg.name};
      dir = "${config.home.homeDirectory}/.local/share/wallpapers/${cfg.name}";
    in
    lib.mkIf (cfg.wallpapers.enable && theme.wallpapers != null) {
      home.file.".local/share/wallpapers/${cfg.name}".source = theme.wallpapers;
      # Defaults layer only — noctalia runtime picks persist separately and win.
      programs.noctalia.settings.wallpaper.directory = lib.mkDefault dir;
    };
}
