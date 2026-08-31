# Named desktop theme registry, consumed by modules/desktop/theme.nix,
# modules/desktop/theme-home.nix and modules/desktop/noctalia-stylix-home.nix.
# Plain Nix — not a flake-parts fragment; import by relative path from the
# consuming module.
#
# One attrset per theme:
#   scheme            — base16 YAML path passed to stylix.base16Scheme
#   polarity          — stylix.polarity
#   override          — stylix.override attrset of bare-hex strings
#   lightPalette      — noctalia light-mode role-mapped hex palette, or null
#                        when the theme has no light variant (dark palette
#                        is reused)
#   trueBlackTerminal — whether OLED true-black terminal deepening
#                        (modules/desktop/theme-home.nix) applies; false when
#                        the theme's own background is part of its identity
#                        (a tint, not near-black)
#   wallpapers         — linkFarm of the theme's wallpaper pack
#                        (lib/themes/wallpapers.nix), or null when the theme
#                        has no pack
{ pkgs }:
let
  wallpaperPacks = import ./wallpapers.nix { inherit pkgs; };

  # Classic base16-schemes: no bespoke override, no light variant, and OLED
  # true-black deepening left off since these track their upstream author's
  # intended dark background rather than a near-black one.
  mkClassic = file: {
    scheme = "${pkgs.base16-schemes}/share/themes/${file}";
    polarity = "dark";
    override = { };
    trueBlackTerminal = false;
    lightPalette = null;
    wallpapers = null;
  };
in
{
  ayu-dark = {
    scheme = "${pkgs.base16-schemes}/share/themes/ayu-dark.yaml";
    polarity = "dark";
    override = {
      base0D = "39BAE6";
    };
    trueBlackTerminal = true;
    wallpapers = null;
    lightPalette = {
      base00 = "#f8f9fa";
      base01 = "#edeff1";
      base02 = "#d2d4d8";
      base03 = "#a0a6ac";
      base04 = "#8A9199";
      base05 = "#5c6166";
      base07 = "#404447";
      base08 = "#f07171";
      base0A = "#f2ae49";
      base0B = "#6cbf49";
      base0C = "#4cbf99";
      base0D = "#399ee6";
      base0E = "#a37acc";
    };
  };

  matte-black = {
    scheme = ./schemes/matte-black.yaml;
    polarity = "dark";
    override = { };
    trueBlackTerminal = true;
    lightPalette = null;
    wallpapers = wallpaperPacks.matte-black;
  };

  # Green-tinted background is the theme's identity; OLED deepening would
  # replace it with plain black and defeat the point of choosing this theme.
  osaka-jade = {
    scheme = ./schemes/osaka-jade.yaml;
    polarity = "dark";
    override = { };
    trueBlackTerminal = false;
    lightPalette = null;
    wallpapers = wallpaperPacks.osaka-jade;
  };

  ristretto = {
    scheme = ./schemes/ristretto.yaml;
    polarity = "dark";
    override = { };
    trueBlackTerminal = false;
    lightPalette = null;
    wallpapers = wallpaperPacks.ristretto;
  };

  tokyo-night = mkClassic "tokyo-night-dark.yaml";
  everforest = mkClassic "everforest.yaml";
  gruvbox-dark-hard = mkClassic "gruvbox-dark-hard.yaml";
  gruvbox-dark-medium = mkClassic "gruvbox-dark-medium.yaml";
  gruvbox-dark-soft = mkClassic "gruvbox-dark-soft.yaml";
  kanagawa = mkClassic "kanagawa.yaml";
  rose-pine = mkClassic "rose-pine.yaml";
  nord = mkClassic "nord.yaml";
  catppuccin-mocha = mkClassic "catppuccin-mocha.yaml";
}
