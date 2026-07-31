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
        base01
        base05
        base0D
        ;
      trueBlack = "#000000";
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
          #
          # Ghostty reads colors.base00 directly when building its theme, so this
          # override genuinely reaches the rendered config. Kitty has no equivalent
          # override — see programs.kitty.extraConfig below for why.
          ghostty.colors.override.base00 = "000000";
        };

      # Kitty renders its palette by calling the base16 scheme object as a
      # functor (`colors { templateRepo; target; }`); mkTarget's
      # colors.override only patches the outer attrset's field access, which
      # that functor closure never reads, so stylix.targets.kitty.colors.override
      # cannot reach the generated theme. Home Manager also emits
      # programs.kitty.settings before the target's `include <theme>` line, so
      # any background/tab-bar keys set in settings are silently discarded by
      # kitty's last-directive-wins config parsing. Both are worked around
      # here: kitty parses top-to-bottom, and lib.mkAfter places this block
      # after that include, making it the effective config.
      programs.kitty.extraConfig = lib.mkAfter ''
        background ${trueBlack}
        active_tab_foreground ${trueBlack}
        active_tab_background ${base0D}
        inactive_tab_foreground ${base05}
        inactive_tab_background ${base01}
      '';
    };
}
