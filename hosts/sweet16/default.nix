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
    ../../profiles/core

    # Ceph Integration
    ../../modules/core/ceph.nix

    # Printing Support
    ../../modules/core/printing.nix

    # Functional Profiles (Suites)
    ../../profiles/desktop
    ../../profiles/development
  ];

  # Machine-specific overrides
  networking.hostName = "sweet16";

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
