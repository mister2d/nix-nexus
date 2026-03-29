{
  den,
  inputs,
  ...
}:
{
  # ============================================================================

  den.aspects.user-ddukes-aspect = {
    includes = [
      den.provides.primary-user
      den.provides.os-user
      den.provides.home-manager
      (den.provides.user-shell "bash")
      "shell-aspect"
      "terminal-aspect"
      "media-aspect"
      "dev-aspect"
    ];

    # Forwarded to {nixos,darwin}.users.users.ddukes
    user = {
      isNormalUser = true;
      group = "users";
      description = "ddukes";
      extraGroups = [
        "networkmanager"
        "wheel"
        "video"
        "audio"
        "input"
        "docker"
        "fuse"
        "render"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQp6H/n2JPSt1VxCAupTC1OTh7R3eu7wO0ZtCNbAkd7"
      ];
    };

    homeManager =
      { pkgs, lib, ... }:
      let
        # Helper for pinned packages
        pin =
          input: pkg:
          (import inputs.${input} {
            inherit (pkgs.stdenv.hostPlatform) system;
            config.allowUnfree = true;
          }).${pkg};

        slicers = pkgs.symlinkJoin {
          name = "slicers";
          paths = [
            (pin "pkgs-terraform" "prusa-slicer")
            (pin "pkgs-terraform" "super-slicer")
          ];
        };
      in
      {
        programs.dev-home.enable = true;

        home = {
          stateVersion = "25.11";
          sessionPath = [ "$HOME/bin" ];
          packages = with pkgs; [
            (import inputs.nixpkgs-chrome {
              inherit (pkgs.stdenv.hostPlatform) system;
              config.allowUnfree = true;
            }).google-chrome
            krita
            (pin "pkgs-hashicorp" "ipmitool")
            (pin "pkgs-terraform" "mqtt-explorer")
            slicers
            (pin "pkgs-vlc" "vlc")
            signal-desktop-bin
            (pin "pkgs-talos" "signalbackup-tools")
            alsa-utils
            wdisplays
            pavucontrol
            brightnessctl
            pamixer
            wl-clipboard
            grim
            slurp
            stress-ng
            wlsunset
            clipman
            networkmanagerapplet
            inotify-tools
            kdePackages.okular
            procps
            kdePackages.kate
            bemenu
            bemoji
            wtype
            easyeffects
            lsp-plugins
            zam-plugins
            mda_lv2
            libsecret
            seahorse
            protonvpn-gui
            yubikey-manager
            libfido2
            graphite-gtk-theme
            adwaita-icon-theme
            gnome-themes-extra
            gtk-engine-murrine
            nerd-fonts.jetbrains-mono
            font-awesome
          ];
        };

        programs.btop = {
          enable = true;
          package = lib.mkDefault pkgs.btop;
          settings = {
            color_theme = "TTY";
            theme_background = false;
            show_gpu_info = true;
          };
        };

        dconf.enable = true;

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

        qt = {
          enable = true;
          platformTheme.name = "gtk";
          style.name = "breeze";
        };

        services.syncthing = {
          enable = true;
          extraOptions = [
            "--no-restart"
            "--no-browser"
          ];
        };
      };
  };
}
