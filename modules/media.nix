{
  lib,
  ...
}:
{

  den.aspects.media-aspect = lib.mkForce {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.television ];
        programs.television = {
          enable = true;
          enableBashIntegration = false;
          settings = {
            tick_rate = 50;
            default_channel = "files";
            history_size = 200;
            ui = {
              ui_scale = 100;
              orientation = "landscape";
              theme = "default";
              input_bar = {
                position = "top";
                prompt = ">";
                border_type = "rounded";
              };
              preview_panel = {
                size = 50;
                scrollbar = true;
                border_type = "rounded";
              };
            };
            shell_integration = {
              fallback_channel = "files";
              keybindings = {
                "smart_autocomplete" = "ctrl-t";
              };
            };
          };
          channels = {
            alias = {
              metadata = {
                name = "alias";
                description = "Shell aliases";
              };
              source = {
                command = "$SHELL -ic 'alias'";
                output = "{split:=:0}";
              };
            };
            dotfiles = {
              metadata = {
                name = "dotfiles";
                description = "User dotfiles";
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
            dirs = {
              metadata = {
                name = "dirs";
                description = "Directories";
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
            bash-history = {
              metadata = {
                name = "bash-history";
                description = "Bash history";
                requirements = [ "bash" ];
              };
              source = {
                command = "sed '1!G;h;$!d' \${HISTFILE:-\${HOME}/.bash_history}";
              };
            };
          };
        };
      };
  };
}
