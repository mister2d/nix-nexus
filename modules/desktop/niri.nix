{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  # Deterministic wait script to ensure Wayland is ready before services start.
  # This eliminates the need for blind sleeps or manual service restarts.
  wait-for-wayland = "${pkgs.bash}/bin/bash -c 'while [ ! -e \"$XDG_RUNTIME_DIR/wayland-1\" ]; do sleep 0.1; done'";
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
  programs.dank-material-shell = {
    enable = true;
    dgop.package = unstable.dgop;
    enableSystemMonitoring = true;
    enableVPN = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
    enableCalendarEvents = true;
    enableClipboardPaste = true;

    # Systemd integration handles the lifecycle via graphical-session.target.
    systemd.enable = true;
  };

  # Systemd User Service Refinements
  # We implement strict deterministic blocking to prevent display connection races.
  systemd.user.services = {
    niri-flake-polkit = {
      description = "PolicyKit Authentication Agent provided by niri-flake";
      after = lib.mkForce [ "graphical-session-pre.target" ];
      partOf = lib.mkForce [ "graphical-session.target" ];
      # DETERMINISM: Wait for socket before attempting to open display.
      serviceConfig = {
        ExecStartPre = wait-for-wayland;
        Restart = lib.mkForce "on-failure";
        RestartSec = lib.mkForce 3;
        # Disable rate limiting to ensure it eventually starts.
        StartLimitIntervalSec = lib.mkForce 0;
      };
      wantedBy = lib.mkForce [ "graphical-session.target" ];
    };

    dms = {
      description = "DankMaterialShell";
      after = [
        "niri-flake-polkit.service"
        "graphical-session.target"
      ];
      requires = [ "niri-flake-polkit.service" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      # DETERMINISM: Wait for socket before attempting to open display.
      serviceConfig = {
        ExecStartPre = wait-for-wayland;
        Restart = "on-failure";
        RestartSec = 3;
        StartLimitIntervalSec = 0;
      };
    };

    easyeffects = {
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      # DETERMINISM: Wait for socket before attempting to open display.
      serviceConfig = {
        ExecStartPre = wait-for-wayland;
        Restart = "on-failure";
        RestartSec = 3;
        StartLimitIntervalSec = 0;
      };
    };
  };

  # Graphics and Hardware optimizations for AMD (ThinkPad Z16)
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
