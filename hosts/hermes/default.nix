_: {
  flake.modules.nixos.hermes-default =
    {
      pkgs,
      inputs,
      nixosModules,
      ...
    }:
    let
      pin = import ../../lib/pinned-pkgs.nix { inherit pkgs; };

      unstablePkgs = pin.pinned inputs.nixpkgs-unstable;
    in
    {
      imports = [
        nixosModules.hardware-proxmox-lxc
        nixosModules.server-default
        nixosModules.core-groot
      ];

      proxmoxLXC.privileged = true;

      security.sudo.enable = false;

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
    };
}
