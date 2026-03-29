{ inputs, ... }:
{
  imports = [
    inputs.den.flakeModules.default
  ];

  # Declare homeConfigurations as mergeable
  options.flake.homeConfigurations = inputs.nixpkgs.lib.mkOption {
    type = inputs.nixpkgs.lib.types.lazyAttrsOf inputs.nixpkgs.lib.types.raw;
    default = { };
  };

  config = {
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    perSystem =
      {
        config,
        pkgs,
        system,
        ...
      }:
      {
        # Tree-wide Validation and Linting
        checks = {
          pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              nixfmt-rfc-style.enable = true;
              deadnix.enable = true;
              statix.enable = true;
            };
          };
        };

        # Developer Environment
        devShells.default = pkgs.mkShell {
          inherit (config.checks.pre-commit-check) shellHook;
          buildInputs = config.checks.pre-commit-check.enabledPackages;
        };
      };
  };
}
