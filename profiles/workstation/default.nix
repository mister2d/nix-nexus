# Registry key: flake.modules.nixos.workstation-default
# Configures: shared workstation defaults for ZFS tuning and WiFi regulatory domain.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.workstation-default =
    {
      pkgs,
      lib,
      nixosModules,
      ...
    }:
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

      # ZFS Performance Profile shared by every workstation. A host overrides
      # any value with a plain assignment (mkDefault loses to mkForce or a
      # bare set).
      nix-nexus.zfs = {
        arcMax = lib.mkDefault 4294967296; # 4GB
        arcMin = lib.mkDefault 1073741824; # 1GB
        arcSysFree = lib.mkDefault 8589934592; # 8GB

        metaLimitPercent = lib.mkDefault 50;
        dnodeLimitPercent = lib.mkDefault 10;
      };

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
