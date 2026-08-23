_: {
  flake.modules.homeManager.avina-home =
    { homeManagerModules, ... }:
    {
      imports = [
        homeManagerModules.user-bash
        homeManagerModules.user-fish
        homeManagerModules.user-neovim-home
        homeManagerModules.user-herdr-home
      ];

      home.stateVersion = "25.11";
    };
}
