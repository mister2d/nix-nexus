{
  lib,
  ...
}:
{

  den.aspects.terminal-aspect = lib.mkForce {
    homeManager =
      { pkgs, ... }:
      let
        colors = {
          background = "#000000";
          foreground = "#d8d8d8";
          cursor = "#00AAAA";
          cursor_text_color = "#000000";
          selection_background = "#00AAAA";
          selection_foreground = "#000000";
          color0 = "#000000";
          color1 = "#f37278";
          color2 = "#a8de7e";
          color3 = "#ffcc70";
          color4 = "#6699cc";
          color5 = "#c594c5";
          color6 = "#00AAAA";
          color7 = "#d8d8d8";
          color8 = "#5e6c6f";
          color9 = "#f69095";
          color10 = "#bee99e";
          color11 = "#ffd994";
          color12 = "#84add6";
          color13 = "#d4afd4";
          color14 = "#00C0C0";
          color15 = "#ffffff";
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
            term = "xterm-256color";
            copy_on_select = "yes";
            "mouse_map shift+left press" = "ungrabbed,grabbed mouse_selection extend";
            background_opacity = "1.0";
            dynamic_background_opacity = "no";
            window_padding_width = 10;
            cursor_shape = "block";
            scrollback_lines = 100000;
            tab_bar_edge = "top";
            tab_bar_style = "powerline";
            active_tab_foreground = "#000000";
            active_tab_background = "#00AAAA";
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
          terminal = "tmux-256color";
          historyLimit = 100000;
          keyMode = "vi";
          mouse = true;
          baseIndex = 1;
          escapeTime = 0;
          shortcut = "a";
          extraConfig = ''
            set -g default-command "${pkgs.bash}/bin/bash"
            set -g status-style bg=black,fg=white
            set -g status-left "#[fg=cyan,bold] #S #[default]| "
            set -g status-right "#[fg=magenta] %Y-%m-%d #[fg=cyan]%H:%M:%S "
            set -g window-status-current-style bg=cyan,fg=black,bold
            bind | split-window -h -c "#{pane_current_path}"
            bind - split-window -v -c "#{pane_current_path}"
            bind h select-pane -L
            bind j select-pane -D
            bind k select-pane -U
            bind l select-pane -R
            set -g pane-border-style fg='#333333'
            set -g pane-active-border-style fg='#00AAAA'
          '';
        };
      };
  };
}
