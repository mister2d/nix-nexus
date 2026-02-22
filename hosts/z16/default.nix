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

    # Functional Profiles (Suites)
    ../../profiles/desktop
    ../../profiles/development
  ];

  # Machine-specific overrides
  networking.hostName = "sweet16";

  environment.systemPackages = with pkgs; [
    # Ceph client for cluster storage integration
    (import inputs.pkgs-ceph {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).ceph-client
  ];

  # Host ID for ZFS (needs to be unique and persistent)
  networking.hostId = "efca0213";
}
