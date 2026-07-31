_: {
  # These stylix.targets options only exist in the HM option tree on hosts
  # that pull in the NixOS stylix module — sweet16 and petunia only.
  flake.modules.homeManager.desktop-theme-home =
    { lib, options, ... }:
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
        };
    };
}
