_: {
  flake.modules.nixos.desktop-default =
    { pkgs, ... }:
    {
      stylix = {
        enable = true;
        # TEMPORARY for C5: every target explicitly off so the plumbing can
        # be proven on both stylix branches before any visual change. Flips
        # in C6.
        autoEnable = false;
        # Keeps the Rust palette generator out of the closure entirely, and
        # keeps noctalia (not hyprpaper) the wallpaper owner.
        image = null;
        polarity = "dark";
        base16Scheme = "${pkgs.base16-schemes}/share/themes/ayu-dark.yaml";
        override.base0D = "39BAE6";
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
}
