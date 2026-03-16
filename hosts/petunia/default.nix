{ ... }:

{
  imports = [
    # Include the results of the hardware scan (generated at install time)
    ./hardware-configuration.nix

    # Machine-specific profiles (Quirks & Hardware)
    ../../profiles/hardware/petunia.nix

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
  networking.hostName = "petunia";

  # Host ID for ZFS (needs to be unique and persistent)
  # Generated randomly for petunia
  networking.hostId = "4e1a0d9b";

  # Enable NVIDIA-specific configurations if needed
  # (Already handled by profile, but can add overrides here)
}
