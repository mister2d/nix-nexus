{
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ../desktop/sway-home.nix
    ../desktop/niri-home.nix
    ../desktop/waybar-home.nix
    ../desktop/notifications.nix
    ./bash.nix
  ];

  # Home Configuration
  home = {
    stateVersion = "25.11";

    # User Applications
    # These are applications installed specifically for the ddukes user.
    packages = with pkgs; [
      # Pin Google Chrome to specific nixpkgs input and allow unfree for that input
      (import inputs.nixpkgs-chrome {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      }).google-chrome

      # Desktop Utilities
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

  # EasyEffects Service (managed via systemd user service)
  services.easyeffects.enable = true;

  # Override the service to launch in a 'bypassed' state (1 = enable bypass)
  # This allows the daemon to load without immediately affecting audio until manually enabled.
  systemd.user.services.easyeffects.Service.ExecStart =
    lib.mkForce "${pkgs.easyeffects}/bin/easyeffects --hide-window --service-mode --bypass 1";

  # XDG Configuration
  xdg.dataFile = {
    # EasyEffects Audio Presets
    # Imports community-maintained presets for superior laptop speaker response.
    # Modern EasyEffects (v7+) uses ~/.local/share instead of ~/.config for presets.
    "easyeffects/output".source = pkgs.fetchFromGitHub {
      owner = "JackHack96";
      repo = "easyeffects-presets";
      rev = "master";
      sha256 = "0c6q0bbi2zlyyq77ngzzn9qrkbf46dpfsws57g43xhykzcgn9gm2";
    };

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
