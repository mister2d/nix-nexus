_: {
  flake.modules.nixos.workstation-default =
    { pkgs, nixosModules, ... }:
    {
      imports = [
        nixosModules.core-boot
        nixosModules.core-networking
        nixosModules.core-nix
        nixosModules.core-security
        nixosModules.core-sops
        nixosModules.core-sshd
        nixosModules.core-sysctl
        nixosModules.core-users
        nixosModules.core-zfs
      ];

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
