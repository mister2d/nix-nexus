{
  lib,
  ...
}:
{

  den.aspects.shell-aspect = lib.mkForce {
    homeManager = _: {
      programs.bash = {
        enable = true;
        shellAliases = {
          ".." = "cd ..";
          "..." = "cd ../..";
          "ll" = "ls -ltr";
          "lrt" = "ls -ltr";
          "tup" = "sudo tailscale up";
          "tdown" = "sudo tailscale down";
          "tstatus" = "tailscale status";
          "tv" = "tv";
        };
        historyControl = [
          "ignoreboth"
          "erasedups"
        ];
        historySize = 100000000;
        historyFileSize = 100000000;
        shellOptions = [
          "histappend"
          "extglob"
          "globstar"
          "checkjobs"
        ];
        enableCompletion = true;
        initExtra = ''
          if [ -f "$HOME/workspace/secrets/github_pat_mcp_server.env" ]; then
            source "$HOME/workspace/secrets/github_pat_mcp_server.env"
          fi

          parse_git_branch() {
            local branch=$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')
            if [ -n "$branch" ]; then
              local status=""
              [[ $(git status --porcelain 2> /dev/null) ]] && status="*"
              echo " ($branch$status)"
            fi
          }

          set_bash_prompt() {
            local exit_status=$?
            local symbol_color=$([[ $exit_status -eq 0 ]] && echo "\033[38;5;64m" || echo "\033[38;5;124m")
            PS1="\[\033[38;5;240m\][\A] \[\033[38;5;64m\]\u@\h \[\033[38;5;33m\]\w\[\033[38;5;135m\]\$(parse_git_branch)\[\033[0m\]\n\[''${symbol_color}\]➜\[\033[0m\] "
          }
          PROMPT_COMMAND="set_bash_prompt''${PROMPT_COMMAND:+; ''${PROMPT_COMMAND}}"

          for cmd in vault boundary consul nomad waypoint; do
            if command -v "$cmd" >/dev/null 2>&1; then complete -C "$(command -v "$cmd")" "$cmd"; fi
          done
          test -s ~/.alias && . ~/.alias || true
        '';
      };

      home.sessionVariables = {
        CONSUL_HTTP_ADDR = "https://consul.service.consul:8501";
        CONSUL_CACERT = "$HOME/.secrets/consul_issuing_ca.pem";
        NOMAD_ADDR = "https://nomad.service.consul:4646";
        VAULT_ADDR = "https://vault.service.consul:8200";
        OMNI_ENDPOINT = "https://omni.novuscotia.com/";
        OMNICONFIG = "$HOME/.config/omni/config";
      };
    };
  };
}
