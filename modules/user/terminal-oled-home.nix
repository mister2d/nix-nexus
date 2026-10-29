# Registry key: flake.modules.homeManager.user-terminal-oled-home
# Configures: the true-black OLED color palette for Kitty.
# Imported by: modules/user/standalone-home.nix (user-standalone-home), hosts/hermes/groot-hm.nix (hm-groot-hermes).
_: {
  flake.modules.homeManager.user-terminal-oled-home =
    _:

    let
      # OLED Aesthetic Palette (Graphite-teal-Dark inspired)
      # True Black #000000 background for power savings and infinite contrast.
      # Vibrant but Balanced Teal #00AAAA for primary accents.
      colors = {
        background = "#000000";
        foreground = "#d8d8d8"; # Light grey for softer readability than pure white
        cursor = "#00AAAA";
        cursor_text_color = "#000000";
        selection_background = "#00AAAA";
        selection_foreground = "#000000";

        # Normal colors
        color0 = "#000000"; # black
        color1 = "#f37278"; # red
        color2 = "#a8de7e"; # green
        color3 = "#ffcc70"; # yellow
        color4 = "#6699cc"; # blue
        color5 = "#c594c5"; # magenta
        color6 = "#00AAAA"; # cyan (vibrant but balanced)
        color7 = "#d8d8d8"; # white

        # Bright colors
        color8 = "#5e6c6f"; # black
        color9 = "#f69095"; # red
        color10 = "#bee99e"; # green
        color11 = "#ffd994"; # yellow
        color12 = "#84add6"; # blue
        color13 = "#d4afd4"; # magenta
        color14 = "#00C0C0"; # cyan (vibrant match)
        color15 = "#ffffff"; # white
      };
    in
    {
      programs = {
        kitty = {
          font = {
            name = "JetBrainsMono Nerd Font";
            size = 14;
          };
          settings = {
            # OLED Optimization
            background_opacity = "1.0";

            # Tab Bar (High Contrast)
            active_tab_foreground = "#000000";
            active_tab_background = "#00AAAA";
            inactive_tab_foreground = "#d8d8d8";
            inactive_tab_background = "#000000";

            # Ported Colors
            inherit (colors)
              background
              foreground
              cursor
              cursor_text_color
              selection_background
              selection_foreground
              color0
              color1
              color2
              color3
              color4
              color5
              color6
              color7
              color8
              color9
              color10
              color11
              color12
              color13
              color14
              color15
              ;
          };
        };
      };
    };
}
