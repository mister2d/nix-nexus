# Registry key: flake.modules.homeManager.user-direnv-home
# Configures: direnv with nix-direnv for automatic devshell loading.
# Imported by: modules/user/home.nix (user-home), modules/user/standalone-home.nix (user-standalone-home).
_: {
  flake.modules.homeManager.user-direnv-home = _: {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
