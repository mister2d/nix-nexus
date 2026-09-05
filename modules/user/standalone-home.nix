# Registry key: flake.modules.homeManager.user-standalone-home
# Configures: the standalone (non-NixOS) Home Manager profile for groot.
# Imported by: hosts/dualie/home.nix (dualie-home), hosts/forge/home.nix (forge-home), hosts/rk3588/home.nix (rk3588-home).
_: {
  flake.modules.homeManager.user-standalone-home =
    { homeManagerModules, ... }:
    {
      imports = [
        homeManagerModules.user-bash
        homeManagerModules.user-fish
        homeManagerModules.user-neovim-home
        homeManagerModules.user-terminal-home
        homeManagerModules.user-terminal-oled-home
        homeManagerModules.user-television-home
        homeManagerModules.user-dev-home
        homeManagerModules.user-herdr-home
      ];

      # Let Home Manager install and manage itself.
      programs.home-manager.enable = true;

      # Allow unfree packages for the Home Manager profile.
      nixpkgs.config.allowUnfree = true;
    };
}
