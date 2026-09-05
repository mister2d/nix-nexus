# Helper: renders the shared multiplexer keymap into tmux bind lines and
# herdr's [keys] table.
#
# Called by: modules/user/herdr-home.nix, modules/user/terminal-home.nix,
# profiles/server/default.nix.
#
# Action fields:
#   group    — section heading, used to group the rendered tmux output
#   key      — canonical key suffix, in herdr's syntax
#   prefixed — whether the leader key is required
#   tmux     — tmux command to bind, or null when tmux already binds this by
#              default and an explicit line would be a no-op
#   herdr    — herdr `[keys]` option name, or null when herdr has no equivalent
{ lib }:

let
  # herdr key syntax -> tmux key syntax
  tmuxKeyNames = {
    "shift+left" = "S-Left";
    "shift+right" = "S-Right";
    "shift+h" = "H";
    "shift+j" = "J";
    "shift+k" = "K";
    "shift+l" = "L";
    "comma" = ",";
    "minus" = "-";
  };

  tmuxKey = key: tmuxKeyNames.${key} or key;

  herdrKey = action: if action.prefixed then "prefix+${action.key}" else action.key;

  # `bind <key> <cmd>` for prefixed actions, `bind -n <Key> <cmd>` otherwise.
  # Keys are padded to the widest key in their group so columns line up.
  renderTmuxGroup =
    actions:
    let
      width = lib.foldl' (acc: a: lib.max acc (lib.stringLength (tmuxKey a.key))) 0 actions;
      line =
        a:
        let
          flag = lib.optionalString (!a.prefixed) "-n ";
          key = tmuxKey a.key;
          padded = key + lib.fixedWidthString (width - lib.stringLength key) " " "";
        in
        "bind ${flag}${padded} ${a.tmux}";
    in
    map line actions;
in
{
  # tmux's `shortcut` option takes the bare letter. herdr wants full chord syntax.
  prefix = {
    tmux = "a";
    herdr = "ctrl+a";
  };

  multiplexer = [
    {
      group = "Easy splits";
      key = "|";
      prefixed = true;
      tmux = ''split-window -h -c "#{pane_current_path}"'';
      herdr = "split_vertical";
    }
    {
      group = "Easy splits";
      key = "minus";
      prefixed = true;
      tmux = ''split-window -v -c "#{pane_current_path}"'';
      herdr = "split_horizontal";
    }

    {
      group = "Vim-style pane selection";
      key = "h";
      prefixed = true;
      tmux = "select-pane -L";
      herdr = "focus_pane_left";
    }
    {
      group = "Vim-style pane selection";
      key = "j";
      prefixed = true;
      tmux = "select-pane -D";
      herdr = "focus_pane_down";
    }
    {
      group = "Vim-style pane selection";
      key = "k";
      prefixed = true;
      tmux = "select-pane -U";
      herdr = "focus_pane_up";
    }
    {
      group = "Vim-style pane selection";
      key = "l";
      prefixed = true;
      tmux = "select-pane -R";
      herdr = "focus_pane_right";
    }

    {
      group = "Vim-style pane swapping";
      key = "shift+h";
      prefixed = true;
      tmux = "swap-pane -s '{left-of}'";
      herdr = "swap_pane_left";
    }
    {
      group = "Vim-style pane swapping";
      key = "shift+j";
      prefixed = true;
      tmux = "swap-pane -s '{down-of}'";
      herdr = "swap_pane_down";
    }
    {
      group = "Vim-style pane swapping";
      key = "shift+k";
      prefixed = true;
      tmux = "swap-pane -s '{up-of}'";
      herdr = "swap_pane_up";
    }
    {
      group = "Vim-style pane swapping";
      key = "shift+l";
      prefixed = true;
      tmux = "swap-pane -s '{right-of}'";
      herdr = "swap_pane_right";
    }

    # tmux binds both prefix+p/n and these. herdr allows exactly one binding
    # per action, so the deliberate no-prefix chord is the one it gets.
    {
      group = "Shift-arrow to switch windows";
      key = "shift+left";
      prefixed = false;
      tmux = "previous-window";
      herdr = "previous_tab";
    }
    {
      group = "Shift-arrow to switch windows";
      key = "shift+right";
      prefixed = false;
      tmux = "next-window";
      herdr = "next_tab";
    }

    # tmux already binds each of these on the prefix by default. Only herdr
    # needs telling, so `tmux = null` keeps the generated tmux.conf free of
    # redundant lines.
    {
      group = "tmux defaults";
      key = "c";
      prefixed = true;
      tmux = null;
      herdr = "new_tab";
    }
    {
      group = "tmux defaults";
      key = "comma";
      prefixed = true;
      tmux = null;
      herdr = "rename_tab";
    }
    {
      group = "tmux defaults";
      key = "1..9";
      prefixed = true;
      tmux = null;
      herdr = "switch_tab";
    }
    {
      group = "tmux defaults";
      key = "x";
      prefixed = true;
      tmux = null;
      herdr = "close_pane";
    }
    {
      group = "tmux defaults";
      key = "z";
      prefixed = true;
      tmux = null;
      herdr = "zoom";
    }
    {
      group = "tmux defaults";
      key = "[";
      prefixed = true;
      tmux = null;
      herdr = "copy_mode";
    }
    {
      group = "tmux defaults";
      key = "d";
      prefixed = true;
      tmux = null;
      herdr = "detach";
    }
  ];

  # Grouped `bind` lines for programs.tmux.extraConfig. Actions with tmux = null
  # are skipped. Groups are emitted in first-appearance order under their heading.
  renderTmux =
    actions:
    let
      bindable = lib.filter (a: a.tmux != null) actions;
      groups = lib.unique (map (a: a.group) bindable);
      block =
        g:
        lib.concatStringsSep "\n" ([ "# ${g}" ] ++ renderTmuxGroup (lib.filter (a: a.group == g) bindable));
    in
    lib.concatStringsSep "\n\n" (map block groups);

  # The herdr `[keys]` table. Actions with herdr = null are skipped.
  renderHerdr =
    actions:
    lib.listToAttrs (
      map (a: lib.nameValuePair a.herdr (herdrKey a)) (lib.filter (a: a.herdr != null) actions)
    );
}
