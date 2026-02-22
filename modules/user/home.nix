{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # Versioned package helpers
  nomad-pkg =
    (import inputs.pkgs-nomad {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).nomad;
  vault-pkg =
    (import inputs.pkgs-hashicorp {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).vault;
  consul-pkg =
    (import inputs.pkgs-hashicorp {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).consul;
  terraform-pkg =
    (import inputs.pkgs-terraform {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).terraform;
  omnictl-pkg =
    (import inputs.pkgs-talos {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).omnictl;
  talosctl-pkg =
    (import inputs.pkgs-talos {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).talosctl;
  meld-pkg =
    (import inputs.pkgs-apps {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).meld;
  helm-pkg =
    (import inputs.pkgs-hashicorp {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).kubernetes-helm;
  butane-pkg =
    (import inputs.pkgs-apps {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).butane;
  envsubst-pkg =
    (import inputs.pkgs-hashicorp {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).envsubst;
  tflint-pkg =
    (import inputs.pkgs-talos {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).tflint;

  # Kubernetes tools
  kubelogin-oidc-pkg =
    (import inputs.pkgs-talos {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).kubelogin-oidc;
  kubectl-rook-ceph-pkg =
    (import inputs.pkgs-talos {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).kubectl-rook-ceph;

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
    ../desktop/niri-home.nix
    ../desktop/waybar-home.nix
    ../desktop/notifications.nix
    ./bash.nix
    ./neovim-home.nix
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

      # --- User Requested Versions ---
      nomad-pkg
      vault-pkg
      consul-pkg
      terraform-pkg
      omnictl-pkg
      talosctl-pkg
      meld-pkg
      helm-pkg
      butane-pkg
      envsubst-pkg
      tflint-pkg
      freelens-bin

      # --- Kubernetes Tools ---
      kubelogin-oidc-pkg
      kubectl-rook-ceph-pkg
      kubectl-doctor

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
      MOZ_ENABLE_WAYLAND = "1";
      SDL_VIDEODRIVER = "wayland";
      QT_QPA_PLATFORM = "wayland";
      NIXOS_OZONE_WL = "1";

      # Editor Configuration
      # Using the absolute path to the user's nixvim wrapper ensures that
      # sudoedit and other system tools consistently use the user's
      # personal configuration even when paths are scrubbed.
      EDITOR = lib.mkForce "/etc/profiles/per-user/ddukes/bin/nvim";
      VISUAL = lib.mkForce "/etc/profiles/per-user/ddukes/bin/nvim";
      SUDO_EDITOR = lib.mkForce "/etc/profiles/per-user/ddukes/bin/nvim";
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
  xdg.dataFile = {
    # --- Konsole Customization ---
    # Creating a custom "Graphite-OLED" theme to match the system's high-contrast
    # Graphite-teal-Dark aesthetic while taking advantage of true blacks.
    "konsole/Graphite-OLED.colorscheme".text = ''
      [General]
      Description=Graphite OLED (Teal)
      Opacity=1
      Wallpaper=

      [Background]
      Color=0,0,0

      [BackgroundIntense]
      Color=25,25,25

      [Foreground]
      Color=216,216,216

      [ForegroundIntense]
      Color=255,255,255

      [Color0]
      Color=0,0,0

      [Color0Intense]
      Color=94,108,111

      [Color1]
      Color=243,114,120

      [Color1Intense]
      Color=246,144,149

      [Color2]
      Color=168,222,126

      [Color2Intense]
      Color=190,233,158

      [Color3]
      Color=255,204,112

      [Color3Intense]
      Color=255,217,148

      [Color4]
      Color=102,153,204

      [Color4Intense]
      Color=132,173,214

      [Color5]
      Color=197,148,197

      [Color5Intense]
      Color=212,175,212

      [Color6]
      Color=93,228,215

      [Color6Intense]
      Color=134,236,226

      [Color7]
      Color=216,216,216

      [Color7Intense]
      Color=255,255,255
    '';

    # Define a Konsole profile that uses the OLED color scheme by default.
    "konsole/Graphite-OLED.profile".text = ''
      [Appearance]
      ColorScheme=Graphite-OLED
      Font=JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0

      [General]
      Name=Graphite OLED
      Parent=FALLBACK/
    '';
  };

  # --- WiFi & Connectivity ---
  # Connectivity is managed via NetworkManager.
  # SSID Strategy:
  # - SSIDs are not hardcoded here to keep this configuration portable and Git-ready.
  # - Operationally, use 'nmtui' or the network applet to first connect to a network.
  # - Passwords are securely persisted by NetworkManager in /etc/NetworkManager/system-connections/
  #   or your local user keyring (libsecret), keeping them out of the Nix store.
}
