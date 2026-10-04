# Registry key: flake.modules.homeManager.user-devenv-home
# Configures: the devenv CLI plus direnv with nix-direnv, so nix-devshell is callable from the shell.
# Imported by: modules/user/home.nix (user-home), modules/user/standalone-home.nix (user-standalone-home).
{ inputs, ... }:
{
  flake.modules.homeManager.user-devenv-home =
    { pkgs, ... }:
    {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      home.packages = [
        inputs.devenv.packages.${pkgs.stdenv.hostPlatform.system}.devenv
      ];
    };
}
