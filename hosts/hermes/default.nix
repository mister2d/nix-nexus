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

          # TPM-sealed personal keys, one per originating host.
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNXL5V23wci0ARBKtji+yLad2Mg0pxIflmq2clUoNVQabpYQbwhIgDHcui1CBqZnA0FdDuVtnsrWzI0XMi3GvQI= ddukes@sweet16 personal (TPM)"
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBwldrZh2sFdX5Z3IyizIlgYBGKLz31t90zokoU/XLcsHGLfZW8RbDwz4c1hGGdjCDlV5eaTMipeqF8a59qiN30= ddukes@petunia personal (TPM)"
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
          settings.Resolve = {
            Cache = "yes";
            CacheFromLocalhost = "yes";
          };
        };

        fstrim.enable = false;
      };

      programs = {
        nix-ld.enable = true;

        singularity = {
          enable = true;
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
