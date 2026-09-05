# Merged into: flake.modules.homeManager.desktop-theme-home
# Configures: the active theme's wallpaper pack and noctalia's default wallpaper directory.
# Imported by: hosts/sweet16/home.nix (sweet16-home), hosts/petunia/home.nix (petunia-home).
# Installs nothing when the active theme carries no wallpaper pack.
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
