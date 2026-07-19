{ inputs, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      # Tree-wide Validation and Linting
      checks.pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
        src = ../../.;
        hooks = {
          # Standard Formatting (RFC 166)
          nixfmt.enable = true;

          # Linting: Unused code and anti-patterns
          deadnix.enable = true;
          statix.enable = true;
        };
      };

      # Development Environment
      # Usage: 'nix develop' to enter environment and install hooks
      devShells.default = pkgs.mkShell {
        inherit (config.checks.pre-commit-check) shellHook;
        buildInputs = config.checks.pre-commit-check.enabledPackages ++ [
          # langfuse is not packaged in nixpkgs; vendored from PyPI, pinned to
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
      };
    };
}
