_:

{
  programs.bash = {
    enable = true;

    # Standard shell aliases
    shellAliases = {
      ".." = "cd ..";
      "..." = "cd ../..";
      "ll" = "ls -ltr";
      "lrt" = "ls -ltr";

      # Tailscale
      "tup" = "sudo tailscale up";
      "tdown" = "sudo tailscale down";
      "tstatus" = "tailscale status";
    };

    # History Control (Nix way)
    historyControl = [
      "ignoreboth"
      "erasedups"
    ];
    historySize = 100000000;
    historyFileSize = 100000000;

    # Shell Options (Nix way)
    shellOptions = [
      "histappend"
      "extglob"
      "globstar"
      "checkjobs"
    ];

    # Enable completion for system and user packages
    enableCompletion = true;

    # Prompt and Custom Logic
    initExtra = ''
            # ------------------------------------------------------------------
            # 6. Custom Prompt: "The Stacked Professional"
            # ------------------------------------------------------------------

            # Git Branch with Status Indicator
            parse_git_branch() {
              # Returns: (master *) or (main)
              local branch
              branch=$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')
              if [ -n "$branch" ]; then
                local status=""
                # Check for uncommitted changes
                if [[ $(git status --porcelain 2> /dev/null) ]]; then
                  status="*"
                fi
                echo " ($branch$status)"
              fi
            }

            # Formatting Constants (raw escape codes, no readline markers)
            BOLD="\033[1m"
            RESET="\033[0m"
            # Solarized-ish Colors
            GREEN="\033[38;5;64m"
            BLUE="\033[38;5;33m"
            PURPLE="\033[38;5;135m"
            RED="\033[38;5;124m"
            GREY="\033[38;5;240m"

            # Build prompt dynamically to handle exit status color
            set_bash_prompt() {
              local exit_status=$?
              local symbol_color
              
              if [ $exit_status -eq 0 ]; then
                symbol_color="$GREEN"
              else
                symbol_color="$RED"
              fi
              
              PS1="\[\033[38;5;240m\][\A] \[\033[38;5;64m\]\u@\h \[\033[38;5;33m\]\w\[\033[38;5;135m\]\$(parse_git_branch)\[\033[0m\]
      \[''${symbol_color}\]➜\[\033[0m\] "
            }

            # Prepend to PROMPT_COMMAND to preserve other hooks (like direnv)
            PROMPT_COMMAND="set_bash_prompt''${PROMPT_COMMAND:+; ''${PROMPT_COMMAND}}"

            # HashiCorp Completions (Dynamic Nix Paths)
            # These are only enabled if the packages are available in the current profile.
            # We use 'command -v' to find the actual location in the Nix store.
            for cmd in vault boundary consul nomad; do
              if command -v "$cmd" >/dev/null 2>&1; then
                complete -C "$(command -v "$cmd")" "$cmd"
              fi
            done

            # Load legacy Aliases if they exist
            test -s ~/.alias && . ~/.alias || true
    '';
  };

  # Environment Variables (Nix way)
  home.sessionVariables = {
    CONSUL_HTTP_ADDR = "https://consul.service.consul:8501";
    CONSUL_CACERT = "$HOME/.secrets/consul_issuing_ca.pem";
    NOMAD_ADDR = "https://nomad.service.consul:4646";
    VAULT_ADDR = "https://vault.service.consul:8200";

    OMNI_ENDPOINT = "https://omni.novuscotia.com/";
    OMNICONFIG = "$HOME/.config/omni/config";
  };
}
