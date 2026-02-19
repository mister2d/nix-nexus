{ pkgs, ... }:

{
  imports = [
    ../../modules/core/boot.nix
    ../../modules/core/networking.nix
    ../../modules/core/security.nix
    ../../modules/core/users.nix
    ../../modules/core/zfs.nix
  ];

  # Allow unfree packages (e.g. vscode, google-chrome)
  nixpkgs.config.allowUnfree = true;

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
}
