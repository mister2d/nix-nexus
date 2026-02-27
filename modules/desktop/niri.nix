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

    # Managed via graphical-session.target for clean separation
    systemd.enable = true;
  };

  # DETERMINISTIC SESSION ARCHITECTURE
  systemd.user.targets.niri-session-ready = {
    description = "Niri Session Ready (Environment Fully Synced)";
    requires = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
  };

  systemd.user.services = {
    # Force Niri to use the Integrated GPU at the systemd unit level.
    # This resolves the '@niri' process appearing on GPU 1.
    niri = {
      serviceConfig.ExecStart = lib.mkForce "${
        inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable
      }/bin/niri --session --render-device /dev/dri/renderD129";
    };

    # Bind critical services to our new deterministic target.
    niri-flake-polkit = {
      description = "PolicyKit Authentication Agent provided by niri-flake";
      wantedBy = lib.mkForce [ "niri-session-ready.target" ];
      after = lib.mkForce [ "niri-session-ready.target" ];
      partOf = lib.mkForce [ "graphical-session.target" ];
      serviceConfig = {
        Restart = lib.mkForce "on-failure";
        RestartSec = lib.mkForce 3;
        StartLimitIntervalSec = lib.mkForce 0;
      };
    };

    dms = {
      description = "DankMaterialShell";
      wantedBy = lib.mkForce [ "niri-session-ready.target" ];
      after = lib.mkForce [ "niri-session-ready.target" ];
      requires = [ "niri-flake-polkit.service" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 3;
        StartLimitIntervalSec = 0;
      };
    };

    easyeffects = {
      wantedBy = lib.mkForce [ "niri-session-ready.target" ];
      after = lib.mkForce [ "niri-session-ready.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
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
