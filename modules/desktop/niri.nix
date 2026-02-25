{ inputs, pkgs, ... }:

let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  imports = [
    inputs.dms.nixosModules.default
    inputs.niri.nixosModules.niri
  ];

  # Niri from Flake
  programs.niri = {
    enable = true;
    package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  };

  # Dank Material Shell (DMS) configuration
  # Using the official NixOS module provided by the dms flake.
  programs.dank-material-shell = {
    enable = true;
    # Use 'dgop' from unstable to satisfy dms requirements for system monitoring.
    dgop.package = unstable.dgop;
    enableSystemMonitoring = true;
    enableVPN = true;
    enableDynamicTheming = true;
  };

  # Niri-specific portal configuration
  # niri-flake includes xdg-desktop-portal-gnome by default, which is required
  # for screencasting and proper shell integration.
  xdg.portal = {
    enable = true;
    # Ensure gnome portal is available for niri
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    config.niri.default = [
      "gnome"
      "gtk"
    ];
  };
}
