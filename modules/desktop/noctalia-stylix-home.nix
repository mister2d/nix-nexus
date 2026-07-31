# Maps the active stylix base16 scheme onto noctalia's "stylix" custom
# palette. Mirrors upstream stylix/modules/noctalia/hm.nix's role mapping for
# the dark variant, sourced live from config.lib.stylix.colors.
#
# The light variant is not covered by upstream (it only ships dark); it is
# derived here against the ayu-light base16 palette using the same role
# mapping, so noctalia's runtime light-mode toggle still resolves the
# "stylix" palette instead of falling back to an undefined one.
_: {
  flake.modules.homeManager.desktop-noctalia-home =
    { config, ... }:
    let
      c = config.lib.stylix.colors.withHashtag;

      # ayu-light base16 hex values (base16-schemes' ayu-light.yaml), mapped
      # through the same roles as upstream's dark variant.
      light = {
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

      mkPalette = p: {
        mPrimary = p.base0D;
        mOnPrimary = p.base00;
        mSecondary = p.base0E;
        mOnSecondary = p.base00;
        mTertiary = p.base0C;
        mOnTertiary = p.base00;
        mError = p.base08;
        mOnError = p.base00;
        mSurface = p.base00;
        mOnSurface = p.base05;
        mHover = p.base0C;
        mOnHover = p.base00;
        mSurfaceVariant = p.base01;
        mOnSurfaceVariant = p.base04;
        mOutline = p.base03;
        mShadow = p.base00;

        terminal = {
          foreground = p.base05;
          background = p.base00;
          cursor = p.base05;
          cursorText = p.base00;
          selectionFg = p.base05;
          selectionBg = p.base02;
          normal = {
            black = p.base00;
            red = p.base08;
            green = p.base0B;
            yellow = p.base0A;
            blue = p.base0D;
            magenta = p.base0E;
            cyan = p.base0C;
            white = p.base05;
          };
          bright = {
            black = p.base03;
            red = p.base08;
            green = p.base0B;
            yellow = p.base0A;
            blue = p.base0D;
            magenta = p.base0E;
            cyan = p.base0C;
            white = p.base07;
          };
        };
      };
    in
    {
      programs.noctalia = {
        customPalettes.stylix = {
          dark = mkPalette c;
          light = mkPalette light;
        };

        settings.theme = {
          source = "custom";
          custom_palette = "stylix";
        };
      };
    };
}
