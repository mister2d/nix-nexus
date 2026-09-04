# Maps the active stylix base16 scheme onto noctalia's "stylix" custom
# palette. Mirrors upstream stylix/modules/noctalia/hm.nix's role mapping for
# the dark variant, sourced live from config.lib.stylix.colors.
#
# The light variant is not covered by upstream (it only ships dark); it comes
# from the active theme's lightPalette in the theme registry (lib/themes),
# mapped through the same roles as upstream's dark variant. Themes without a
# light palette fall back to the dark palette instead of an undefined one.
_: {
  flake.modules.homeManager.desktop-noctalia-home =
    {
      config,
      osConfig,
      pkgs,
      ...
    }:
    let
      colors = config.lib.stylix.colors.withHashtag;

      theme = (import ../../lib/themes { inherit pkgs; }).${osConfig.nix-nexus.theme.name};
      light = if theme.lightPalette != null then theme.lightPalette else colors;

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
          dark = mkPalette colors;
          light = mkPalette light;
        };

        settings.theme = {
          source = "custom";
          custom_palette = "stylix";
        };
      };
    };
}
