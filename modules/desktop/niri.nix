{
  inputs,
  pkgs,
  ...
}:

let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      # Globally disable tests for niri to prevent build failures in ISO/resource-constrained environments.
      niri = prev.niri.overrideAttrs (old: {
        doCheck = false;
      });
    })
  ];

  imports = [
    # DMS 1.4 Stable NixOS Module
    inputs.dms.nixosModules.default
    inputs.niri.nixosModules.niri
  ];

  # Niri Configuration
  # HEEDING THE WARNING: Using niri 25.11 from nixpkgs as required by DMS.
  programs.niri = {
    enable = true;
    # Force the package override to ensure tests are skipped system-wide.
    package = lib.mkForce (pkgs.niri.overrideAttrs (old: {
      doCheck = false;
    }));
  };

  # Dank Material Shell (DMS) configuration
  programs.dank-material-shell = {
    enable = true;
    dgop.package = unstable.dgop;
    enableSystemMonitoring = true;
    enableVPN = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
    enableCalendarEvents = true;
    enableClipboardPaste = true;

    # PARENT/CHILD MODEL: Disable systemd to allow niri.enableSpawn to manage launch.
    systemd.enable = false;
  };

  # Systemd User Service Scoping
  systemd.user.services = {
    # DANK LINUX 1.4 DOCS FIX: Disable niri-flake's polkit agent.
    # The DMS built-in agent is the sole authentication authority.
    niri-flake-polkit.enable = false;

    # Generic service scoping for background daemons
    easyeffects = {
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
    };
  };

  # Graphics and Hardware optimizations (Generic)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd # OpenCL for AMD
    ];
  };

  security.polkit.enable = true;

  # Essential System Services
  services = {
    accounts-daemon.enable = true;
    upower.enable = true;

    # Display Manager (Greetd) - Isolated to Niri
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --cmd niri-session";
          user = "greeter";
        };
      };
    };
  };

  # Additional system tools for Niri/DMS
  environment.systemPackages = with pkgs; [
    unstable.dsearch
    unstable.xwayland-satellite
    qt6.qtwayland
    kdePackages.qtwayland
  ];
}
