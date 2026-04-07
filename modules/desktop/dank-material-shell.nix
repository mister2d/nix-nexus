{
  inputs,
  pkgs,
  lib,
  config,
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
    # DMS 1.4 Stable NixOS Module
    inputs.dms.nixosModules.default
  ];

  # Dank Material Shell (DMS) configuration
  config = lib.mkIf config.programs.dank-material-shell.enable {
    programs.dank-material-shell = {
      dgop.package = unstable.dgop;
      enableSystemMonitoring = true;
      enableVPN = true;
      enableDynamicTheming = true;
      enableAudioWavelength = true;
      enableCalendarEvents = true;
      enableClipboardPaste = true;

      # PARENT/CHILD MODEL: Disable systemd to allow compositor to manage launch.
      # This is the default for Niri integration but can be overridden.
      systemd.enable = lib.mkDefault false;
    };

    # Additional system tools for DMS
    environment.systemPackages = with pkgs; [
      unstable.dsearch
      unstable.xwayland-satellite
    ];
  };
}
