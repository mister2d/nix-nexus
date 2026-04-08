{ pkgs, ... }:

{
  # Television: Blazingly fast general purpose fuzzy finder TUI.
  # This module manages the global 'tv' configuration, specialized cable channels,
  # and seamless shell integration for a modern, high-performance CLI workflow.
  home.packages = [ pkgs.television ];

  programs.television = {
    enable = true;
    enableBashIntegration = false;

    # Primary Configuration (config.toml)
    # ----------------------------------
    # Optimized for a large-screen, landscape layout with a focus on
    # speed and visibility.
    settings = {
      tick_rate = 50;
      default_channel = "files";
      history_size = 200;
      global_history = false;

      ui = {
        ui_scale = 100;
        orientation = "landscape";
        theme = "default";

        input_bar = {
          position = "top";
          prompt = ">";
          border_type = "rounded";
        };

        status_bar = {
          separator_open = "";
          separator_close = "";
          hidden = false;
        };

        results_panel = {
          border_type = "rounded";
        };

        preview_panel = {
          size = 50;
          scrollbar = true;
          border_type = "rounded";
          hidden = false;
        };

        help_panel = {
          show_categories = true;
          hidden = true;
        };

        remote_control = {
          show_channel_descriptions = true;
          sort_alphabetically = true;
        };
      };

      # Global Keybindings
      # ------------------
      keybindings = {
        esc = "quit";
        ctrl-c = "quit";

        down = "select_next_entry";
        ctrl-n = "select_next_entry";
        ctrl-j = "select_next_entry";
        up = "select_prev_entry";
        ctrl-p = "select_prev_entry";
        ctrl-k = "select_prev_entry";

        ctrl-up = "select_prev_history";
        ctrl-down = "select_next_history";

        tab = "toggle_selection_down";
        backtab = "toggle_selection_up";
        enter = "confirm_selection";

        pagedown = "scroll_preview_half_page_down";
        pageup = "scroll_preview_half_page_up";

        ctrl-y = "copy_entry_to_clipboard";
        ctrl-r = "reload_source";
        ctrl-s = "cycle_sources";

        ctrl-t = "toggle_remote_control";
        ctrl-o = "toggle_preview";
        ctrl-h = "toggle_help";
        f12 = "toggle_status_bar";
        ctrl-l = "toggle_layout";

        backspace = "delete_prev_char";
        ctrl-w = "delete_prev_word";
        ctrl-u = "delete_line";
        delete = "delete_next_char";
        left = "go_to_prev_char";
        right = "go_to_next_char";
        home = "go_to_input_start";
        ctrl-a = "go_to_input_start";
        end = "go_to_input_end";
        ctrl-e = "go_to_input_end";
      };

      events = {
        mouse-scroll-up = "scroll_preview_up";
        mouse-scroll-down = "scroll_preview_down";
      };

      # Shell Integration
      # -----------------
      # Triggers specific channels when <CTRL-T> is pressed after a command.
      shell_integration = {
        fallback_channel = "files";
        channel_triggers = {
          "alias" = [
            "alias"
            "unalias"
          ];
          "env" = [
            "export"
            "unset"
          ];
          "dirs" = [
            "cd"
            "ls"
            "rmdir"
          ];
          "files" = [
            "cat"
            "less"
            "head"
            "tail"
            "vim"
            "nano"
            "bat"
            "cp"
            "mv"
            "rm"
            "touch"
            "chmod"
            "chown"
            "ln"
            "tar"
            "zip"
            "unzip"
            "gzip"
            "gunzip"
            "xz"
          ];
          "git-diff" = [
            "git add"
            "git restore"
          ];
          "git-branch" = [
            "git checkout"
            "git branch"
            "git merge"
            "git rebase"
            "git pull"
            "git push"
          ];
          "git-log" = [
            "git log"
            "git show"
          ];
          "docker-images" = [ "docker run" ];
          "git-repos" = [
            "nvim"
            "code"
            "hx"
            "git clone"
          ];
        };
        keybindings = {
          "smart_autocomplete" = "ctrl-t";
        };
      };
    };

    # Custom Cable Channels
    # ---------------------
    # These channels extend 'tv' beyond simple file finding, enabling
    # navigational mastery over shell aliases, dotfiles, and system history.
    channels = {
      # 1. Shell Aliases
      alias = {
        metadata = {
          name = "alias";
          description = "A channel to select from shell aliases";
        };
        source = {
          command = "$SHELL -ic 'alias'";
          output = "{split:=:0}";
        };
      };

      # 2. Dotfiles (Config)
      dotfiles = {
        metadata = {
          name = "dotfiles";
          description = "A channel to select from your user's dotfiles";
          requirements = [
            "fd"
            "bat"
          ];
        };
        source = {
          command = "fd -t f . $HOME/.config";
        };
        preview = {
          command = "bat -n --color=always '{}'";
        };
      };

      # 3. Directory Navigation
      dirs = {
        metadata = {
          name = "dirs";
          description = "A channel to select from directories";
          requirements = [ "fd" ];
        };
        source = {
          command = [
            "fd -t d"
            "fd -t d --hidden"
          ];
        };
        preview = {
          command = "ls -la --color=always '{}'";
        };
        keybindings = {
          shortcut = "f2";
        };
      };

      # 4. Bash History
      bash-history = {
        metadata = {
          name = "bash-history";
          description = "A channel to select from your bash history";
          requirements = [ "bash" ];
        };
        source = {
          command = "sed '1!G;h;$!d' \${HISTFILE:-\${HOME}/.bash_history}";
        };
      };
    };
  };
}
