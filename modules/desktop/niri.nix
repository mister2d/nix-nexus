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

    # RESEARCH FIX: Disable the global systemd service.
    # We use the Home Manager module's 'enableSpawn' for deterministic Niri integration.
    systemd.enable = false;
  };

  # Systemd User Service Scoping
  systemd.user.services = {
    # RESEARCH FIX: Explicitly disable the niri-flake polkit agent.
    # DMS provides its own, and running both causes contention and display errors.
    niri-flake-polkit.enable = false;

    # Ensure background daemons only start when a graphical session is reached.
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
