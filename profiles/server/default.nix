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
        nixosModules.core-security
        nixosModules.core-sysctl
        nixosModules.core-users
      ];

      nixpkgs.config.allowUnfree = true;

      environment.variables = {
        # Disable the nixos-rebuild upgrade daemon for LXC compatibility.
        # Prevents "Failed to start transient service unit" errors.
        NIXOS_REBUILD_UPGRADE_DAEMON = "0";
      };

      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        substituters = [
          "https://cache.nixos.org"
          "https://devenv.cachix.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjE="
          "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        ];
        trusted-users = [
          "root"
          "ddukes"
          "groot"
        ];
        max-jobs = 4;
        cores = 2;
      };

      time.timeZone = "America/New_York";
    };
}
