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
      pin = import ../../lib/pinned-pkgs.nix { inherit pkgs; };

      unstablePkgs = pin.pinned inputs.nixpkgs-unstable;
    in
    {
      imports = [
        (modulesPath + "/virtualisation/proxmox-lxc.nix")
        nixosModules.server-default
        nixosModules.core-groot
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
