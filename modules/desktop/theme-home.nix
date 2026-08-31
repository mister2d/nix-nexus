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
        base02
        base05
        base0C
        base0D
        base0E
        ;
      trueBlack = "#000000";
    in
    {
      # stylix's cursor module (stylix/hm/cursor.nix) sets home.pointerCursor's
      # name/package/size/x11.enable/gtk.enable but never .enable itself, and
      # Home Manager has deprecated inferring enablement from a non-null config.
      # Set it explicitly so cursor config generation keeps working without warning.
      home.pointerCursor.enable = true;

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
          # can't be split out cleanly; they're overridden below instead via
          # a mkAfter block, the same last-directive-wins mechanism kitty uses.
          tmux.enable = false;

          kitty.enable = true;
          ghostty.enable = true;
          btop.enable = true;
          gtk.enable = true;
          qt.enable = true;
          hyprland.enable = true;
          hyprlock.enable = true;

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

      # terminal-home's tmux extraConfig carries the non-stylix fallback
      # colors. stylix's tmux target stays disabled above because
      # extraConfig is types.lines, so this mkAfter block restates only the
      # color-bearing directives — tmux parses top-to-bottom and the last
      # directive wins, the same mechanism the kitty workaround above uses.
      programs.tmux.extraConfig = lib.mkAfter ''
        set -g status-style bg=${base00},fg=${base05}
        set -g status-left "#[fg=${base0D},bold] #S #[default]| "
        set -g status-right "#[fg=${base0E}] %Y-%m-%d #[fg=${base0C}]%H:%M:%S "
        set -g window-status-current-style bg=${base0D},fg=${base00},bold
        set -g pane-border-style fg='${base02}'
        set -g pane-active-border-style fg='${base0C}'
      '';
    };
}
