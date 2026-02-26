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

    # DETERMINISM: Enable systemd service but force it to wait for the session.
    systemd.enable = true;
  };

  # Systemd User Service Refinements
  # We override services to ensure they wait for the graphical session environment.
  systemd.user.services = {
    dms = {
      description = "DankMaterialShell";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
    };
    easyeffects = {
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
    };
    niri-flake-polkit = {
      # Fix the polkit agent starting too early
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
    };
  };

  # Graphics and Hardware optimizations for AMD (ThinkPad Z16)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd # OpenCL for AMD
    ];
  };

  # Ensure polkit and dconf are enabled (DMS dependencies)
  services.accounts-daemon.enable = true;
  services.upower.enable = true;
  security.polkit.enable = true;

  # Additional system tools for Niri/DMS
  environment.systemPackages = with pkgs; [
    unstable.dsearch
    unstable.xwayland-satellite
    # Essential for Qt apps (Krita, etc.) to run on Wayland
    qt6.qtwayland
    kdePackages.qtwayland
  ];
}
