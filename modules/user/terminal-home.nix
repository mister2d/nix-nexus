{ pkgs, ... }:

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
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 13;
    };
    settings = {
      # Standard terminfo for broad compatibility (fixes 'xterm-kitty' missing on remote hosts)
      term = "xterm-256color";

      # OLED Optimization
      background_opacity = "1.0";
      dynamic_background_opacity = "no";

      # Padding
      window_padding_width = 10;

      # Cursor
      cursor_shape = "block";
      cursor_blink_interval = "0.5";

      # Scrollback
      scrollback_lines = 100000;

      # Tab Bar (High Contrast)
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
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

  programs.tmux = {
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
    # Prefix set to Ctrl-a (traditional Screen/Common choice)
    shortcut = "a";

    extraConfig = ''
      # OLED High-Contrast Status Bar
      set -g status-style bg=black,fg=white
      set -g status-left "#[fg=cyan,bold] #S #[default]| "
      set -g status-right "#[fg=magenta] %Y-%m-%d #[fg=cyan]%H:%M:%S "
      set -g window-status-current-style bg=cyan,fg=black,bold
      set -g window-status-format " #I:#W "
      set -g window-status-current-style bg=cyan,fg=black,bold
      set -g window-status-current-format " #I:#W "

      # Easy splits (Screen-like but intuitive)
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
      # This allows seamless navigation between Tmux and Neovim.
      set -g pane-border-style fg='#333333'
      set -g pane-active-border-style fg='#00AAAA'
    '';
  };
}
