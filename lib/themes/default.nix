# Named desktop theme registry, consumed by modules/desktop/theme.nix and
# modules/desktop/noctalia-stylix-home.nix. Plain Nix — not a flake-parts
# fragment; import by relative path from the consuming module.
#
# One attrset per theme:
#   scheme       — base16 YAML path passed to stylix.base16Scheme
#   polarity     — stylix.polarity
#   override     — stylix.override attrset of bare-hex strings
#   lightPalette — noctalia light-mode role-mapped hex palette, or null when
#                  the theme has no light variant (dark palette is reused)
{ pkgs }:
{
  ayu-dark = {
    scheme = "${pkgs.base16-schemes}/share/themes/ayu-dark.yaml";
    polarity = "dark";
    override = {
      base0D = "39BAE6";
    };
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
}
