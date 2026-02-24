{ ... }:

{
  imports = [
    ../../modules/programs/common.nix
    ../../modules/programs/dev.nix
    ../../modules/programs/scripts.nix
  ];

  # Include user-level development tools via Home Manager
  home-manager.users.ddukes = {
    imports = [ ../../modules/user/dev-home.nix ];
  };
}
