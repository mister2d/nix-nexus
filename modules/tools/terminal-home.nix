_: {
  flake.modules.homeManager.user-terminal-home =
    { pkgs, ... }:

    {
      programs = {
        kitty = {
          enable = true;
          settings = {
            # Standard terminfo for broad compatibility
            term = "xterm-256color";

            # Mouse behavior
            copy_on_select = "yes";
            # Click then Shift-Click to select range
            "mouse_map shift+left press" = "ungrabbed,grabbed mouse_selection extend";
            "mouse_map shift+left click" = "ungrabbed,grabbed mouse_selection extend";
            # Right-click to paste from clipboard
            "mouse_map right press" = "ungrabbed,grabbed paste_from_clipboard";

            # OLED Optimization
            dynamic_background_opacity = "no";

            # Padding
            window_padding_width = 10;
            hide_window_decorations = "yes";

            # Cursor
            cursor_shape = "block";
            cursor_blink_interval = "0.5";

            # Scrollback
            scrollback_lines = 100000;

            # Tab Bar (High Contrast)
            tab_bar_edge = "top";
            tab_bar_style = "powerline";
          };
        };

        ghostty = {
          enable = true;
          settings = {
            term = "xterm-256color";

            cursor-style = "block";
            cursor-style-blink = true;

            scrollback-limit = 100000;

            window-padding-x = 10;
            window-padding-y = 10;
            window-decoration = false;
            gtk-tabs-location = "top";

            # Mouse behavior
            copy-on-select = "clipboard";
            # Right-click pastes from the clipboard instead of opening a context menu
            right-click-action = "paste";
            # Shift always extends the selection, even while a program such as tmux
            # has mouse reporting enabled
            mouse-shift-capture = "never";
            mouse-hide-while-typing = true;
          };
        };

        tmux = {
          enable = true;
          shell = "${pkgs.bash}/bin/bash";
          # Standard terminal for compatibility with legacy tools like screen
          terminal = "tmux-256color";
          historyLimit = 100000;
          keyMode = "vi";
          mouse = true;
          baseIndex = 1;
          escapeTime = 0; # Fix for Neovim lag

          # Approachable Screen-like bindings while learning Tmux
          shortcut = "a";

          extraConfig = ''
            # Fix mangled PATH on non-NixOS hosts (e.g. dualie/Debian)
            # By default tmux starts a login shell, which often resets the PATH.
            # Setting default-command to bash ensures it starts a non-login shell.
            set -g default-command "${pkgs.bash}/bin/bash"

            # OLED High-Contrast Status Bar
            set -g status-style bg=black,fg=white
            set -g status-left "#[fg=cyan,bold] #S #[default]| "
            set -g status-right "#[fg=magenta] %Y-%m-%d #[fg=cyan]%H:%M:%S "
            set -g window-status-current-style bg=cyan,fg=black,bold
            set -g window-status-format " #I:#W "
            set -g window-status-current-style bg=cyan,fg=black,bold
            set -g window-status-current-format " #I:#W "

            # Easy splits
            bind | split-window -h -c "#{pane_current_path}"
            bind - split-window -v -c "#{pane_current_path}"
            unbind '"'
            unbind %

            # Vim-style pane selection
            bind h select-pane -L
            bind j select-pane -D
            bind k select-pane -U
            bind l select-pane -R

            # Shift-arrow to switch windows
            bind -n S-Left  previous-window
            bind -n S-Right next-window

            # Smart pane switching with awareness of Vim splits.
            set -g pane-border-style fg='#333333'
            set -g pane-active-border-style fg='#00AAAA'

            # Right-click to paste from the tmux buffer
            bind-key -n MouseDown3Pane paste-buffer

            # Copies leave tmux over OSC 52, which also works across SSH.
            # terminal-features matches the outer terminal's TERM, which kitty and
            # ghostty both set to xterm-256color.
            set -g set-clipboard on
            set -as terminal-features ',xterm-256color:clipboard'

            # Wheel scroll enters copy-mode, but passes through to full-screen
            # mouse-aware programs (vim, less, htop). -e exits copy-mode on
            # reaching the bottom.
            bind -n WheelUpPane if -Ft= '#{mouse_any_flag}' 'send -M' \
              "if -Ft= '#{pane_in_mode}' 'send -M' 'copy-mode -e'"

            # Vi-style selection in copy-mode
            bind -T copy-mode-vi v send -X begin-selection
            bind -T copy-mode-vi y send -X copy-pipe-and-cancel
            bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-pipe-no-clear
          '';
        };
      };
    };
}
