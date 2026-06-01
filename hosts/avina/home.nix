_: {
  flake.modules.homeManager.avina-home =
    { homeManagerModules, ... }:
    {
      imports = [
        homeManagerModules.user-bash
        homeManagerModules.user-neovim-home
      ];

      home.stateVersion = "25.11";
    };
}
