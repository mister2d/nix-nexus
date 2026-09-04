_: {
  flake.modules.homeManager.user-home =
    {
      pkgs,
      lib,
      inputs,
      homeManagerModules,
      ...
    }:

    let
      pin = import ../../lib/pinned-pkgs.nix { inherit pkgs; };

      # Environment packages
      terraform-pkgs = pin.pinned inputs.pkgs-terraform;
      ipmitool-pkg = (pin.pinned inputs.pkgs-hashicorp).ipmitool;
      mqtt-explorer-pkg = terraform-pkgs.mqtt-explorer;
      super-slicer-pkg = terraform-pkgs.super-slicer;
      prusa-slicer-pkg = terraform-pkgs.prusa-slicer;
      vlc-pkg = (pin.pinned inputs.pkgs-vlc).vlc;
      signalbackup-tools-pkg = (pin.pinned inputs.pkgs-talos).signalbackup-tools;

      # Unstable packages for user-level tools
      unstable-pkgs = pin.pinned inputs.nixpkgs-unstable;

      # Vivaldi from unstable, paired with the codecs build that exports
      # av_dynamic_hdr_smpte2094_app5_to_t35
      vivaldi = unstable-pkgs.vivaldi.override {
        proprietaryCodecs = true;
        inherit (pin.pinned inputs.pkgs-vivaldi-codecs) vivaldi-ffmpeg-codecs;
      };

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
        homeManagerModules.user-bash
        homeManagerModules.user-fish
        homeManagerModules.user-neovim-home
        homeManagerModules.user-terminal-home
        homeManagerModules.user-television-home
        homeManagerModules.user-ceph-mount
        homeManagerModules.user-ssh
        homeManagerModules.user-audio-effects
        homeManagerModules.user-audio-routing
        homeManagerModules.user-dev-home
        homeManagerModules.user-herdr-home
      ];

      # Development Home Profile
      programs.dev-home.enable = true;

      # Home Configuration
      home = {
        stateVersion = "25.11";

        # User Applications
        # These are applications installed specifically for the ddukes user.
        packages = with pkgs; [
          # Pin Google Chrome to specific nixpkgs input and allow unfree for that input
          (pin.pinned inputs.nixpkgs-chrome).google-chrome

          # Browsers
          unstable-pkgs.firefox
          vivaldi

          # --- Environment Tools ---
          krita
          ipmitool-pkg
          mqtt-explorer-pkg
          slicers
          vlc-pkg
          signal-desktop
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
          kdePackages.okular # PDF viewer
          procps # System process utilities
          kdePackages.kate # Advanced text editor
          bemenu # Dynamic menu (replaces dmenu)
          bemoji # Emoji picker
          wtype # Virtual keyboard input
          easyeffects # System-wide audio effects
          lsp-plugins # Essential plugins for EasyEffects
          zam-plugins # EasyEffects zam-plugins-lv2
          mda_lv2 # EasyEffects mda.lv2

          # Sync (manual invocation — service autostart disabled)
          syncthing

          # Secret Management & VPN
          libsecret # DBus interface for secrets (CLI: secret-tool)
          seahorse # GNOME GUI for managing keys and passwords
          unstable-pkgs.proton-vpn # Official ProtonVPN GTK client (not in 25.11)

          # Yubikey & FIDO2 Tools
          yubikey-manager # GUI/CLI to manage YubiKeys
          libfido2 # Authentication library for FIDO2 devices

          # Appearance & Themes
          adwaita-icon-theme # Core theme engine/icons (fixes GTK module errors)
          gnome-themes-extra # Provides Adwaita theme engine
          gtk-engine-murrine # Murrine engine for various GTK themes

          # Fonts
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
        # Default to generic package. Hosts override with rocmSupport/cudaSupport.
        package = lib.mkDefault pkgs.btop;
        settings = {
          theme_background = false;
          show_gpu_info = true;
        };
      };

      # Enable dconf (required for EasyEffects and portals)
      dconf.enable = true;

      # Appearance (GTK/Theming)
      gtk = {
        enable = true;
        iconTheme = {
          name = "Adwaita";
          package = pkgs.adwaita-icon-theme;
        };
      };

      # Qt Integration
      qt.enable = true;

      # User Services
      services.syncthing.enable = false;

      # Activation Scripts
      # These scripts run during Home Manager activation to handle session state.
      home.activation = { };

      # XDG Configuration
      xdg.dataFile = { };

      # --- WiFi & Connectivity ---
      # Connectivity is managed via NetworkManager.
      # SSID Strategy:
      # - SSIDs are not hardcoded here to keep this configuration portable and Git-ready.
      # - Operationally, use 'nmtui' or the network applet to first connect to a network.
      # - Passwords are securely persisted by NetworkManager in /etc/NetworkManager/system-connections/
      #   or your local user keyring (libsecret), keeping them out of the Nix store.
    };
}
