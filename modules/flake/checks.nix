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
        buildInputs = config.checks.pre-commit-check.enabledPackages;
      };
    };
}
