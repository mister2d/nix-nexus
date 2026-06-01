{ nixosModules, ... }:

{
  imports = [
    # Declarative Disk Partitioning (LUKS + ZFS)
    ./disko.nix

    # Include the results of the hardware scan (generated at install time)
    ./hardware-configuration.nix

    # Machine-specific profiles (Quirks & Hardware)
    ../../profiles/hardware/petunia.nix

    # Core System Profile (Every machine gets this)
    ../../profiles/workstation

    # Ceph Integration
    nixosModules.core-ceph

    # Printing Support
    nixosModules.core-printing

    # Functional Profiles (Suites)
    ../../profiles/desktop
    ../../profiles/development

    # Compositor
    ../../modules/desktop/sway.nix
  ];

  # Machine-specific overrides
  networking.hostName = "petunia";

  # ZFS Workstation Tuning (AI/ML & Coding)
  nix-nexus.zfs = {
    # Assuming 64GB RAM (Swap is 66G).
    # 16GB ARC is a good balance for datasets without starving GPU/Apps.
    arcMax = 17179869184; # 16GB
    arcMin = 4294967296; # 4GB
    arcSysFree = 8589934592; # 8GB (Generous headroom for GPU/drivers/OOM safety)

    # Coding & Small Files optimization
    metaLimitPercent = 80;
    dnodeLimitPercent = 20;
  };

  # Host ID for ZFS (needs to be unique and persistent)
  # Generated randomly for petunia
  networking.hostId = "4e1a0d9b";

  # Enable NVIDIA-specific configurations if needed
  # (Already handled by profile, but can add overrides here)
}
