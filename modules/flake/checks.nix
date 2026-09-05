# Flake assembly: devshell. Sets devenv.shells.default and checks.pre-commit-check.
# Composes the devenv devshell, git-hooks lint suite, and Claude Code wiring.
{ inputs, ... }:
{
  imports = [ inputs.devenv.flakeModule ];

  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      # Development Environment
      # Usage: 'nix develop' to enter environment and install hooks
      devenv.shells.default = {
        packages = [
          # JS/TS runtime for the context-mode plugin's execution sandbox.
          pkgs.bun

          # Secrets tooling. sops/age edit and encrypt the files consumed by
          # core-sops. ssh-to-age derives a host's age recipient from its SSH
          # host key. secretspec comes from nixpkgs-unstable because the stable
          # channel lags (0.10.1 vs 0.13.0).
          pkgs.sops
          pkgs.age
          pkgs.ssh-to-age
          inputs.nixpkgs-unstable.legacyPackages.${system}.secretspec

          # langfuse is not packaged in nixpkgs. Vendored from PyPI, pinned to
          # satisfy the Claude Code Stop hook's >=4.0,<5 constraint.
          (pkgs.python3.withPackages (ps: [
            (ps.buildPythonPackage {
              pname = "langfuse";
              version = "4.14.0";
              format = "wheel";
              src = pkgs.fetchurl {
                url = "https://files.pythonhosted.org/packages/76/c7/ca0f591e1184415ffcd920a4107f3d2638ab5af7ff7e498d99a9b8b2bb13/langfuse-4.14.0-py3-none-any.whl";
                hash = "sha256-Yyt0q/oU2a09zL4zIr9+EbDc6b4N5FGw0TTbm/8kbUQ=";
              };
              propagatedBuildInputs = [
                ps.httpx
                ps.pydantic
                ps.backoff
                ps.wrapt
                ps.packaging
                ps.opentelemetry-api
                ps.opentelemetry-sdk
                ps.opentelemetry-exporter-otlp-proto-http
              ];
              doCheck = false;
              pythonImportsCheck = [ "langfuse" ];
            })
          ]))
        ];

        # Tree-wide Validation and Linting
        git-hooks.hooks = {
          # Standard Formatting (RFC 166)
          nixfmt.enable = true;

          # Linting: Unused code and anti-patterns
          deadnix.enable = true;
          statix.enable = true;
        };

        # Claude Code integration: generates .claude/settings.json and
        # .mcp.json from these options. Hook scripts and .claude/agents/*.md
        # stay hand-authored. Only the wiring is declared here.
        claude.code = {
          enable = true;

          hooks = {
            # devenv auto-enables this hook (runs prek after every
            # Edit/MultiEdit/Write) once git-hooks.enable is true. Disabled
            # to keep exactly the three hooks below — no added automation.
            git-hooks-run.enable = false;

            commit-reminder = {
              hookType = "PostToolUse";
              matcher = "^Bash$";
              command = ''bash "$CLAUDE_PROJECT_DIR"/.agents/scripts/hook-commit-reminder.sh'';
            };
            push-guard = {
              hookType = "PreToolUse";
              matcher = "^Bash$";
              command = ''bash "$CLAUDE_PROJECT_DIR"/.agents/scripts/hook-push-guard.sh'';
            };
            # Credentials come from secretspec (secretspec.toml) rather than the
            # shell environment, so they reach only this process. --reason is
            # mandatory under 0.13's require_reason policy. Both `secretspec` and
            # the vendored-langfuse `python3` are devshell-only, so this adds no
            # dependency the hook did not already have.
            langfuse = {
              hookType = "Stop";
              command = ''secretspec run --reason "langfuse trace export" -- python3 "$CLAUDE_PROJECT_DIR"/.claude/hooks/langfuse_hook.py'';
            };
          };

          mcpServers.nixos-tools = {
            type = "stdio";
            command = "mcp-nixos";
          };
        };
      };

      # Tree-wide Validation and Linting (nix flake check)
      checks.pre-commit-check = config.devenv.shells.default.git-hooks.run;
    };
}
