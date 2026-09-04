# herdr — terminal multiplexer with first-class coding-agent awareness.
#
# Keybindings come from lib/keymap.nix, the same source tmux renders from, so
# the leader key, splits, pane navigation and window switching behave
# identically in both. herdr allows exactly one binding per action, so where
# tmux binds two chords (prefix+p/n and Shift-arrow for window nav) herdr gets
# the no-prefix chord.
#
# theme.name = "terminal" makes herdr draw from the outer terminal's ANSI
# palette. That is already stylix-themed for ddukes and the true-black OLED
# palette for groot, so one setting covers both users. On stylix hosts the
# sidebar tokens are additionally pinned to the base16 scheme.
_: {
  flake.modules.homeManager.user-herdr-home =
    {
      pkgs,
      lib,
      config,
      inputs,
      ...
    }:

    let
      pin = import ../../lib/pinned-pkgs.nix { inherit pkgs; };

      unstable-pkgs = pin.pinned inputs.nixpkgs-unstable;

      inherit (unstable-pkgs) herdr;
      keymap = import ../../lib/keymap.nix { inherit lib; };

      stylixColors = lib.optionalAttrs (config.lib ? stylix) (
        let
          c = config.lib.stylix.colors.withHashtag;
        in
        {
          custom = {
            accent = c.base0D;
            panel_bg = c.base00;
            surface0 = c.base01;
            surface1 = c.base02;
            surface_dim = c.base01;
            overlay0 = c.base03;
            overlay1 = c.base04;
            text = c.base05;
            subtext0 = c.base04;
            red = c.base08;
            peach = c.base09;
            yellow = c.base0A;
            green = c.base0B;
            teal = c.base0C;
            blue = c.base0D;
            mauve = c.base0E;
          };
        }
      );

      settings = {
        onboarding = false;

        theme = {
          name = "terminal";
        }
        // stylixColors;

        keys = {
          prefix = keymap.prefix.herdr;
        }
        // keymap.renderHerdr keymap.multiplexer;

        # Nix owns the binary, so `herdr update` cannot succeed and the
        # background version check only produces nags. The agent-detection
        # manifest check writes to the config dir and stays on.
        update.version_check = false;

        # Resume Claude Code and friends into their native conversation
        # sessions when the herdr server restarts.
        session.resume_agents_on_restore = true;

        worktrees.directory = "~/.herdr/worktrees";
      };

      tomlFormat = pkgs.formats.toml { };
      rawConfig = tomlFormat.generate "herdr-config.toml" settings;

      # `herdr config check` is hermetic — no $HOME, no network — and exits 1
      # on any unknown key or invalid binding. Running it here turns a keymap
      # typo into a build failure instead of a binding silently disabled at
      # runtime.
      checkedConfig = pkgs.runCommand "herdr-config.toml" { } ''
        HERDR_CONFIG_PATH=${rawConfig} ${herdr}/bin/herdr config check
        cp ${rawConfig} "$out"
      '';
    in
    {
      home.packages = [ herdr ];

      xdg.configFile."herdr/config.toml".source = checkedConfig;
    };
}
