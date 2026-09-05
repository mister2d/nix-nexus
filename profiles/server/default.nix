# Registry key: flake.modules.nixos.server-default
# Configures: the base profile for headless NixOS servers and LXC containers.
# Imported by: hosts/avina/default.nix (avina-default), hosts/hermes/default.nix (hermes-default).
# Omits: modules/core/boot.nix, modules/core/zfs.nix, modules/core/networking.nix.
_: {
  flake.modules.nixos.server-default =
    { nixosModules, lib, ... }:
    let
      keymap = import ../../lib/keymap.nix { inherit lib; };
    in
    {
      imports = [
        nixosModules.core-nix
        nixosModules.core-security
        nixosModules.core-sops
        nixosModules.core-sshd
        nixosModules.core-sysctl
        nixosModules.core-users
      ];

      environment.variables = {
        # Disable the nixos-rebuild upgrade daemon for LXC compatibility.
        # Prevents "Failed to start transient service unit" errors.
        NIXOS_REBUILD_UPGRADE_DAEMON = "0";
      };

      nix.settings = {
        max-jobs = 4;
        cores = 2;
      };

      # System State Version
      # Do not change this after the initial installation.
      system.stateVersion = "25.11";

      # Session Multiplexer:
      # Persistent sessions for long-running deploys and maintenance.
      programs.tmux = {
        enable = true;
        shortcut = "a";
        baseIndex = 1;
        escapeTime = 0;
        keyMode = "vi";
        terminal = "tmux-256color";
        extraConfig = ''
          set -g status-style bg=black,fg=cyan
          set -g status-left "#[fg=cyan,bold] #S #[default]| "

          ${keymap.renderTmux keymap.multiplexer}
        '';
      };
    };
}
