_: {
  flake.modules.nixos.hermes-default =
    {
      pkgs,
      inputs,
      modulesPath,
      nixosModules,
      ...
    }:
    let
      unstablePkgs = import inputs.nixpkgs-unstable {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
    in
    {
      imports = [
        (modulesPath + "/virtualisation/proxmox-lxc.nix")
        nixosModules.server-default
      ];

      proxmoxLXC = {
        privileged = true;
        manageNetwork = false;
      };

      networking = {
        hostName = "hermes";
        networkmanager.enable = false;
        firewall.enable = false;
      };

      users.users.groot = {
        isNormalUser = true;
        extraGroups = [ "kvm" ];
        shell = pkgs.bash;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQp6H/n2JPSt1VxCAupTC1OTh7R3eu7wO0ZtCNbAkd7"
        ];
      };

      security.sudo.enable = false;

      systemd.network = {
        enable = true;
        networks."10-eth0" = {
          matchConfig.Name = "eth0";
          networkConfig.DHCP = "yes";
        };
      };

      services = {
        resolved = {
          enable = true;
          extraConfig = ''
            Cache=true
            CacheFromLocalhost=true
          '';
        };

        fstrim.enable = false;
      };

      programs = {
        nix-ld.enable = true;

        singularity = {
          enable = true;
          enableSuid = true;
          package = unstablePkgs.apptainer;
          systemBinPaths = [ "/run/current-system/sw/bin" ];
        };

        tmux = {
          enable = true;
          shortcut = "a";
          baseIndex = 1;
          escapeTime = 0;
          keyMode = "vi";
          terminal = "tmux-256color";
          extraConfig = ''
            set -g status-style bg=black,fg=cyan
            set -g status-left "#[fg=cyan,bold] #S #[default]| "
            bind | split-window -h -c "#{pane_current_path}"
            bind - split-window -v -c "#{pane_current_path}"
          '';
        };
      };

      system.stateVersion = "25.11";
    };
}
