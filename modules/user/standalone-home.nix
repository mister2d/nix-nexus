# Registry key: flake.modules.homeManager.user-standalone-home
# Configures: the standalone (non-NixOS) Home Manager profile for groot.
# Imported by: hosts/dualie/home.nix (dualie-home), hosts/forge/home.nix (forge-home), hosts/rk3588/home.nix (rk3588-home).
_: {
  flake.modules.homeManager.user-standalone-home =
    { homeManagerModules, pkgs, ... }:
    let
      nixPackage = import ../../lib/nix-package.nix pkgs;
    in
    {
      imports = [
        homeManagerModules.user-bash
        homeManagerModules.user-fish
        homeManagerModules.user-neovim-home
        homeManagerModules.user-terminal-home
        homeManagerModules.user-terminal-oled-home
        homeManagerModules.user-television-home
        homeManagerModules.user-devenv-home
        homeManagerModules.user-herdr-home
        homeManagerModules.user-xdg
      ];

      # Same Nix version as the NixOS fleet (lib/nix-package.nix). Home Manager's nix.package only
      # selects the package for generated config; home.packages puts it on PATH. The nix-daemon
      # on these hosts is not managed here (docs/non-nixos.md).
      nix.package = nixPackage;
      home.packages = [ nixPackage ];

      # Let Home Manager install and manage itself.
      programs.home-manager.enable = true;

      # Allow unfree packages for the Home Manager profile.
      nixpkgs.config.allowUnfree = true;
    };
}
