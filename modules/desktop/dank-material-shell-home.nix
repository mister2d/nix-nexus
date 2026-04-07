{
  pkgs,
  inputs,
  ...
}:

let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  imports = [
    inputs.dms.homeModules.default
    inputs.dms.homeModules.niri
  ];

  # DMS 1.4 Stable Configuration (Home Manager)
  programs.dank-material-shell = {
    enable = true;
    dgop.package = unstable.dgop;

    # PARENT/CHILD MODEL: Use enableSpawn for native inheritance.
    # HEEDING WARNINGS: Enable includes to provide required DMS UI fragments.
    niri = {
      includes.enable = true;
      enableSpawn = true;
      enableKeybinds = false;
    };
  };

  # Required dependencies for DMS background operations
  home.packages = with pkgs; [
    matugen
    cliphist
  ];
}
