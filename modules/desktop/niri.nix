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
    # DMS 1.4 Stable NixOS Module
    inputs.dms.nixosModules.default
    inputs.niri.nixosModules.niri
  ];

  # Niri Configuration
  # HEEDING THE WARNING: Using niri 25.11 from nixpkgs as required by DMS.
  programs.niri = {
    enable = true;
    package = pkgs.niri;
  };

  # Dank Material Shell (DMS) 1.4 stable configuration
  programs.dank-material-shell = {
    enable = true;
    dgop.package = unstable.dgop;
    enableSystemMonitoring = true;
    enableVPN = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
    enableCalendarEvents = true;
    enableClipboardPaste = true;

    # Managed via graphical-session.target for better logging and management
    systemd.enable = true;
  };

  # Systemd User Service Scoping
  systemd.user.services = {
    # DANK LINUX 1.4 DOCS FIX: Disable niri-flake's polkit agent.
    # The DMS built-in agent is the sole authentication authority.
    niri-flake-polkit.enable = false;

    # RCA FIX: Explicitly force services to use Wayland and inherit display from session.
    # We remove hardcoded WAYLAND_DISPLAY/DISPLAY to allow inheritance from startup sync.
    dms = {
      description = "DankMaterialShell";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig.Environment = [
        "GDK_BACKEND=wayland"
        "QT_QPA_PLATFORM=wayland"
        "MOZ_ENABLE_WAYLAND=1"
        "ELECTRON_OZONE_PLATFORM_HINT=wayland"
      ];
    };

    easyeffects = {
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig.Environment = [
        "GDK_BACKEND=wayland"
      ];
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
