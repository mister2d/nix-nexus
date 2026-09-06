# Merged into: flake.modules.homeManager.user-herdr-home
# Configures: herdr, a terminal multiplexer with coding-agent session awareness.
# Imported by: modules/user/home.nix (user-home), modules/user/standalone-home.nix (user-standalone-home), hosts/avina/home.nix (avina-home), hosts/hermes/groot-hm.nix (hm-groot-hermes).
# Keybindings come from lib/keymap.nix, the same source tmux renders from.
# theme.name "terminal" reads the outer terminal's ANSI palette for both users.
# Stylix hosts also pin the sidebar tokens to the active base16 scheme.
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
          colors = config.lib.stylix.colors.withHashtag;
        in
        {
          custom = {
            accent = colors.base0D;
            panel_bg = colors.base00;
            surface0 = colors.base01;
            surface1 = colors.base02;
            surface_dim = colors.base01;
            overlay0 = colors.base03;
            overlay1 = colors.base04;
            text = colors.base05;
            subtext0 = colors.base04;
            red = colors.base08;
            peach = colors.base09;
            yellow = colors.base0A;
            green = colors.base0B;
            teal = colors.base0C;
            blue = colors.base0D;
            mauve = colors.base0E;
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

      # `herdr config check` is hermetic — no $HOME, no network. It exits 1
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

      # Copied, not symlinked. herdr rewrites config.toml in place whenever a
      # setting changes inside the TUI — theme, agent panel sort — and a
      # store symlink fails that write with "Read-only file system", which
      # takes the Settings screen with it. The Nix-rendered baseline is
      # reinstalled on every activation, so TUI edits last until the next
      # home-manager switch. The rm -f clears the symlink a previous
      # generation left behind; install would follow it and fail against the
      # store instead of replacing it.
      home.activation.herdrConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${pkgs.coreutils}/bin/rm -f "${config.xdg.configHome}/herdr/config.toml"
        run ${pkgs.coreutils}/bin/install -Dm0644 \
          ${checkedConfig} "${config.xdg.configHome}/herdr/config.toml"
      '';
    };
}
