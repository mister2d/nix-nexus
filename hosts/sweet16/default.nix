{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan (generated at install time)
    ./hardware-configuration.nix

    # Machine-specific profiles (Quirks & Hardware)
    ../../profiles/hardware/z16.nix

    # Core System Profile (Every machine gets this)
    ../../profiles/workstation

    # Ceph Integration
    ../../modules/core/ceph.nix

    # Printing Support
    ../../modules/core/printing.nix

    # Functional Profiles (Suites)
    ../../profiles/desktop
    ../../profiles/development

    # Compositors & Desktop Environments
    ../../modules/desktop/niri.nix
    ../../modules/desktop/dank-material-shell.nix
  ];

  # Machine-specific overrides
  networking.hostName = "sweet16";

  # Tailscale roaming: accept-routes is suppressed on home SSIDs (LAN is directly
  # reachable) and enabled everywhere else (road/hotspot access to LAN resources).
  nix-nexus.tailscale.homeSSIDs = [
    "Trial"
  ];

  # Prevent NVMe from entering ps 4 (9500µs exit latency); caps at ps 3 (1200µs) for ZFS
  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=9000" ];

  # ZFS Performance Profile (Coding & General Purpose)
  nix-nexus.zfs = {
    # Assuming 32GB RAM.
    # 8GB ARC is a good balance for a mobile workstation.
    arcMax = 8589934592; # 8GB
    arcMin = 2147483648; # 2GB
    arcSysFree = 4294967296; # 4GB (Safety margin for Nix builds)

    # Coding & Development Optimization
    metaLimitPercent = 85;
    dnodeLimitPercent = 25;
  };

  environment.systemPackages =
    let
      # Use pinned Ceph input for consistency
      ceph-pkgs = import inputs.pkgs-ceph {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
    in
    with pkgs;
    [
      # Ceph Integration:
      # - ceph: Provides 'ceph-fuse' for user-space mounts
      # - ceph-client: Provides 'ceph', 'rados', 'rbd' and other essential tools
      ceph-pkgs.ceph
      ceph-pkgs.ceph-client
    ];

  # Host ID for ZFS (needs to be unique and persistent)
  networking.hostId = "efca0213";
}
