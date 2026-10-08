# Registry key: flake.modules.homeManager.user-fish
# Configures: Fish shell packages, aliases, and abbreviations.
# Imported by: modules/user/home.nix (user-home), modules/user/standalone-home.nix (user-standalone-home), hosts/avina/home.nix (avina-home), hosts/hermes/groot-hm.nix (hm-groot-hermes).
_: {
  flake.modules.homeManager.user-fish =
    { pkgs, ... }:

    let
      sharedAliases = import ../../lib/shell-aliases.nix;
    in
    {
      home.packages = with pkgs; [
        eza
        yazi
        wikiman
        bat-extras.core
      ];

      programs.fish = {
        enable = true;
        generateCompletions = true;

        shellAliases = sharedAliases;

        shellAbbrs = {
          # Tool replacements
          diff = "kitten diff";
          grep = "rg -n --color=auto";
          man = "batman";
          more = "less -mrFX";

          # Location shortcuts
          cd-bl = "cd $BUILD";
          cd-wk = "cd ~/workspace";
          cd-src = "cd ~/src";

          # History
          h-se = "history --show-time=\"[%F %T] \" ";
          h-ls = "history --show-time=\"[%F %T] \" | bat -l log";
          h-de = "history --show-time=\"[%F %T] \" delete";
        };

        functions = {
          # Enter the nix-devshell devShell by git reference, no local clone
          # required. --latest overrides llm-agents to the upstream flake
          # tip for a bleeding-edge agent-harness CLI escape hatch,
          # bypassing nix-devshell's own committed flake.lock pin.
          devenv-devshell = ''
            set -l shell full
            set -l latest 0
            for arg in $argv
                switch $arg
                    case --latest
                        set latest 1
                    case '*'
                        set shell $arg
                end
            end
            if test $latest -eq 1
                nix develop --refresh --no-write-lock-file \
                    --override-input llm-agents github:numtide/llm-agents.nix \
                    "git+ssh://gitea@code-ssh.novuscotia.com/novuscotia-ops/nix-devshell#$shell"
            else
                nix develop --refresh \
                    "git+ssh://gitea@code-ssh.novuscotia.com/novuscotia-ops/nix-devshell#$shell"
            end
          '';
        };
      };
    };
}
