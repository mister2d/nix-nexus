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
  imports = [
    inputs.dms.nixosModules.default
    inputs.niri.nixosModules.niri
  ];

  # Niri from Flake
  programs.niri = {
    enable = true;
    package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  };

  # Dank Material Shell (DMS) system-level dependencies
  programs.dank-material-shell = {
    enable = true;
    dgop.package = unstable.dgop;
    enableSystemMonitoring = true;
    enableVPN = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
    enableCalendarEvents = true;
    enableClipboardPaste = true;

    # We manage the service via Home Manager's niri integration
    systemd.enable = false;
  };

  # Systemd User Service Scoping
  systemd.user.services = {
    # DANK LINUX DOCS FIX: Disable niri-flake's polkit agent.
    # DMS 1.5 provides its own agent; running both causes display errors and crashes.
    niri-flake-polkit.enable = false;

    # Ensure EasyEffects waits for the graphical session
    easyeffects = {
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
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
