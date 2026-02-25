{ pkgs, ... }:

let
  # OLED Aesthetic Palette (Graphite-teal-Dark inspired)
  # True Black #000000 background for power savings and infinite contrast.
  # Teal #00FFFF / #59f2e6 for primary accents.
  colors = {
    primary = {
      background = "#000000";
      foreground = "#d8d8d8"; # Light grey for softer readability than pure white
    };
    cursor = {
      text = "#000000";
      cursor = "#00ffff";
    };
    normal = {
      black = "#000000";
      red = "#f37278";
      green = "#a8de7e";
      yellow = "#ffcc70";
      blue = "#6699cc";
      magenta = "#c594c5";
      cyan = "#59f2e6";
      white = "#d8d8d8";
    };
    bright = {
      black = "#5e6c6f";
      red = "#f69095";
      green = "#bee99e";
      yellow = "#ffd994";
      blue = "#84add6";
      magenta = "#d4afd4";
      cyan = "#86ece2";
      white = "#ffffff";
    };
  };
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        padding = {
          x = 10;
          y = 10;
        };
        dynamic_padding = true;
        decorations = "none";
        opacity = 1.0;
      };

      font = {
        normal = {
          family = "JetBrainsMono Nerd Font";
          style = "Regular";
        };
        bold = {
          family = "JetBrainsMono Nerd Font";
          style = "Bold";
        };
        size = 13.0;
      };

      inherit colors;

      selection = {
        semantic_escape_chars = ",│`|:\"' ()[]{}<>\t";
        save_to_clipboard = true;
      };

      cursor = {
        style = {
          shape = "Block";
          blinking = "On";
        };
      };

      scrolling = {
        history = 100000;
      };
    };
  };

  programs.tmux = {
    enable = true;
    shell = "${pkgs.bash}/bin/bash";
    terminal = "alacritty";
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
      set -g pane-active-border-style fg='#00ffff'
    '';
  };
}
