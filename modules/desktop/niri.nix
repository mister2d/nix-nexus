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
  # We use the system-wide programs.niri from niri-flake.
  # This sets up the systemd session and the niri-session binary.
  programs.niri = {
    enable = true;
    package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  };

  # Dank Material Shell (DMS) configuration
  # The DMS module handles its own systemd services and dependencies.
  programs.dank-material-shell = {
    enable = true;
    # Use 'dgop' from unstable to satisfy dms requirements for system monitoring.
    dgop.package = unstable.dgop;
    enableSystemMonitoring = true;
    enableVPN = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
    enableCalendarEvents = true;
    enableClipboardPaste = true;

    # We start DMS manually in niri-home.nix to ensure environment sync.
    systemd.enable = false;
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
