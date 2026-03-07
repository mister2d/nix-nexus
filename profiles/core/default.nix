{ pkgs, ... }:

{
  imports = [
    ../../modules/core/boot.nix
    ../../modules/core/networking.nix
    ../../modules/core/security.nix
    ../../modules/core/sysctl.nix
    ../../modules/core/users.nix
    ../../modules/core/zfs.nix
  ];

  # Allow unfree packages (e.g. vscode, google-chrome)
  nixpkgs.config.allowUnfree = true;

  # Nix Package Manager Settings
  nix.settings = {
    # Nix-specific experimental features
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Binary Caches for Devenv toolchain
    substituters = [
      "https://cache.nixos.org"
      "https://devenv.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjE="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];

    # Ensure users can use the binary caches
    trusted-users = [
      "root"
      "ddukes"
      "groot"
    ];

    # Limit the number of parallel build jobs to 8 to avoid memory exhaustion
    # on this 16-thread system (32GB RAM). Each heavy compilation job (e.g., LLVM/Chromium)
    # can easily consume 2-4GB of RAM.
    max-jobs = 8;

    # Allow each job to use up to 2 CPU cores, balancing throughput and memory pressure.
    cores = 2;
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
}
