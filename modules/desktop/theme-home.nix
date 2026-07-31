_: {
  # These stylix.targets options only exist in the HM option tree on hosts
  # that pull in the NixOS stylix module — sweet16 and petunia only.
  flake.modules.homeManager.desktop-theme-home =
    {
      lib,
      options,
      config,
      ...
    }:
    let
      inherit (config.lib.stylix.colors.withHashtag)
        base00
        base01
        base05
        base0D
        ;
    in
    {
      stylix.targets =
        # The stylix v5 noctalia target (customPalettes) only exists on the
        # stylix master branch (petunia); sweet16 pins release-26.05, which
        # lacks it. Guard so this file can be shared by both hosts.
        lib.optionalAttrs (options.stylix.targets ? noctalia) {
          # Palette mapping will be owned here in a later commit; upstream's
          # v5 target would otherwise write the same customPalettes keys,
          # a hard conflict.
          noctalia.enable = false;
        }
        // {
          # noctalia owns the wallpaper, not hyprpaper.
          hyprland.hyprpaper.enable = false;
          # colorschemes.nightfox reaches all 7 configs and can't be removed
          # without drifting five of them.
          nixvim.enable = false;
          # programs.tmux.extraConfig is types.lines, so its colour lines
          # can't be split out without reordering the generated tmux.conf
          # and drifting four hosts.
          tmux.enable = false;

          kitty.enable = true;
          ghostty.enable = true;
          btop.enable = true;

          # OLED: keep terminals true black. ayu-dark's base00 is #0b0e14, but this
          # panel runs pure #000000 today and that preference is deliberate. Scoped to
          # the terminals — a global stylix.override.base00 would also move noctalia
          # surfaces, GTK/Qt backgrounds and btop.
          kitty.colors.override.base00 = "000000";
          ghostty.colors.override.base00 = "000000";
        };

      # Tab-bar colours have no stylix equivalent. active_tab_foreground uses
      # the global base00 (not the pure-black terminal override above) so the
      # tab bar stays legible against the base0D accent without wiring the
      # OLED override into a second location.
      programs.kitty.settings = {
        active_tab_foreground = base00;
        active_tab_background = base0D;
        inactive_tab_foreground = base05;
        inactive_tab_background = base01;
      };
    };
}
