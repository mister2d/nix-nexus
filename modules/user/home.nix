{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # Environment packages
  ipmitool-pkg =
    (import inputs.pkgs-hashicorp {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).ipmitool;
  mqtt-explorer-pkg =
    (import inputs.pkgs-terraform {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).mqtt-explorer;
  super-slicer-pkg =
    (import inputs.pkgs-terraform {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).super-slicer;
  prusa-slicer-pkg =
    (import inputs.pkgs-terraform {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).prusa-slicer;
  vlc-pkg =
    (import inputs.pkgs-vlc {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).vlc;
  signalbackup-tools-pkg =
    (import inputs.pkgs-talos {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).signalbackup-tools;

  # Handle slicer conflicts by joining them with symlinkJoin
  slicers = pkgs.symlinkJoin {
    name = "slicers";
    paths = [
      prusa-slicer-pkg
      super-slicer-pkg
    ];
  };
in
{
  imports = [
    ../desktop/sway-home.nix
    ../desktop/waybar-home.nix
    ../desktop/notifications.nix
    ./bash.nix
    ./neovim-home.nix
    ./terminal-home.nix
    ./ceph-mount.nix
    ./audio-effects.nix
  ];

  # Home Configuration
  home = {
    stateVersion = "25.11";

    # Add $HOME/bin to user's PATH
    sessionPath = [
      "$HOME/bin"
    ];

    # User Applications
    # These are applications installed specifically for the ddukes user.
    packages = with pkgs; [
      # Pin Google Chrome to specific nixpkgs input and allow unfree for that input
      (import inputs.nixpkgs-chrome {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      }).google-chrome

      # --- Environment Tools ---
      krita
      ipmitool-pkg
      mqtt-explorer-pkg
      slicers
      vlc-pkg
      signal-desktop-bin
      signalbackup-tools-pkg

      # Desktop Utilities
      alsa-utils # Provides alsamixer
      wdisplays # Display management for Wayland
      pavucontrol # PulseAudio/PipeWire volume control
      brightnessctl # Screen brightness control
      pamixer # Command-line mixer
      wl-clipboard # Wayland clipboard utilities
      grim # Screenshot utility
      slurp # Select region for screenshots
      stress-ng # Stress Workload testing
      wlsunset # Night light for Wayland
      clipman # Clipboard manager
      networkmanagerapplet # WiFi/Network management tray icon
      inotify-tools # File watch utilities
      procps # System process utilities
      kdePackages.kate # Advanced text editor
      bemenu # Dynamic menu (replaces dmenu)
      bemoji # Emoji picker
      wtype # Virtual keyboard input
      easyeffects # System-wide audio effects
      lsp-plugins # Essential plugins for EasyEffects

      # Appearance & Themes
      graphite-gtk-theme # OLED-optimized dark theme
      adwaita-icon-theme # Core theme engine/icons (fixes GTK module errors)
      gnome-themes-extra # Provides Adwaita theme engine
      gtk-engine-murrine # Murrine engine for various GTK themes

      # Fonts
      nerd-fonts.jetbrains-mono
      font-awesome
    ];

    # Wayland Session Environment
    # These variables optimize application behavior for the Wayland desktop.
    sessionVariables = {
      MOZ_ENABLE_WAYLAND = lib.mkForce "1";
      SDL_VIDEODRIVER = lib.mkForce "wayland";
      NIXOS_OZONE_WL = lib.mkForce "1";

      # Editor Configuration
      # Using the absolute path to the user's nixvim wrapper ensures that
      # sudoedit and other system tools consistently use the user's
      # personal configuration even when paths are scrubbed.
      EDITOR = lib.mkForce "/etc/profiles/per-user/ddukes/bin/nvim";
      VISUAL = lib.mkForce "/etc/profiles/per-user/ddukes/bin/nvim";
      SUDO_EDITOR = lib.mkForce "/etc/profiles/per-user/ddukes/bin/nvim";
    };
  };

  # Resource Monitor
  programs.btop = {
    enable = true;
    # Enable ROCm SMI support for AMD GPU monitoring
    package = pkgs.btop.override { rocmSupport = true; };
    settings = {
      color_theme = "TTY";
      theme_background = false;
      show_gpu_info = true;
    };
  };

  # Enable dconf (required for EasyEffects and portals)
  dconf.enable = true;

  # Appearance (GTK/Theming)
  # Optimized for OLED displays to improve visibility and reduce power consumption.
  gtk = {
    enable = true;
    theme = {
      name = "Graphite-teal-Dark";
      package = pkgs.graphite-gtk-theme.override {
        themeVariants = [ "teal" ];
        colorVariants = [ "dark" ];
      };
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };

  # Qt Integration
  # Ensures Qt applications match the system's GTK theme for a consistent UI.
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "breeze";
  };

  # User Services
  # These services run in the background for the current user.
  services.syncthing = {
    enable = true;
    # Disable the internal monitor process to allow systemd to manage the lifecycle
    # directly. This ensures only one 'syncthing' process appears in the list.
    extraOptions = [
      "--no-restart"
      "--no-browser"
    ];
  };

  # XDG Configuration
  xdg.dataFile = { };

  # --- WiFi & Connectivity ---
  # Connectivity is managed via NetworkManager.
  # SSID Strategy:
  # - SSIDs are not hardcoded here to keep this configuration portable and Git-ready.
  # - Operationally, use 'nmtui' or the network applet to first connect to a network.
  # - Passwords are securely persisted by NetworkManager in /etc/NetworkManager/system-connections/
  #   or your local user keyring (libsecret), keeping them out of the Nix store.
}
