_: {
  flake.modules.nixos.workstation-default =
    { pkgs, nixosModules, ... }:
    {
      imports = [
        nixosModules.core-boot
        nixosModules.core-networking
        nixosModules.core-security
        nixosModules.core-sysctl
        nixosModules.core-users
        nixosModules.core-zfs
      ];

      # Nix Package Manager Settings
      nix.settings = {
        # Nix-specific experimental features
        experimental-features = [
          "nix-command"
          "flakes"
        ];

        # Global Binary Caches
        # These ensure that specialized toolchains (like Devenv 2.0) are pulled
        # as pre-built binaries rather than triggered into failing local builds.
        substituters = [
          "https://cache.nixos.org"
          "https://devenv.cachix.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjE="
          "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        ];

        # Trusted Users: Allow specific accounts to utilize the binary caches.
        trusted-users = [
          "root"
          "ddukes"
          "groot"
        ];
      };

      # Set Timezone
      time.timeZone = "America/New_York";

      # Global Wireless Regulatory Domain
      # This ensures the WiFi card uses the correct frequency bands for the US
      # across all machines, avoiding "World Mode" restrictions.
      systemd.services.set-wireless-regdom = {
        description = "Set Wireless Regulatory Domain to US";
        after = [ "network.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.iw}/bin/iw reg set US";
        };
        wantedBy = [ "multi-user.target" ];
      };

      # System State Version
      # Do not change this after the initial installation.
      system.stateVersion = "25.11";
    };
}
