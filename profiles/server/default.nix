# profiles/server — Base profile for headless NixOS servers and LXC containers.
#
# Intentionally omits:
#   modules/core/boot.nix  — LUKS, systemd initrd; meaningless in a container
#   modules/core/zfs.nix   — ZFS pool management, devNodes, ARC tuning
#   modules/core/networking.nix — workstation networking (NetworkManager, WiFi,
#                                 mDNS, Google Cast, Syncthing, Tailscale)
#
# Hosts importing this profile set boot.isContainer = true (or their own boot
# config) and configure networking (firewall, interface) in their own default.nix.
_: {
  flake.modules.nixos.server-default =
    { nixosModules, ... }:
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
    };
}
