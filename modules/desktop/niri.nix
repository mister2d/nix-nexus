{ inputs, pkgs, ... }:

let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  imports = [ inputs.dms.nixosModules.default ];

  # Niri from Flake
  programs.niri = {
    enable = true;
    package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri;
  };

  # DMS from Flake, using unstable for missing dependencies like 'dgop'
  # We use a 'nixpkgs.overlays' to make sure the DMS module can find its
  # dependencies if it looks in the standard 'pkgs' set.
  nixpkgs.overlays = [
    (_final: _prev: {
      inherit (unstable) dgop;
    })
  ];

  programs.dank-material-shell.enable = true;
}
