_:

{
  # ZFS (Zettabyte File System) Configuration
  # ZFS provides advanced data integrity and snapshot capabilities.
  boot = {
    supportedFilesystems = [ "zfs" ];

    # Ensure the ZFS module is available early in the boot process.
    initrd.kernelModules = [ "zfs" ];

    # ZFS Boot Options
    zfs = {
      # Force import the root pool (improves reliability during boot/recovery).
      forceImportRoot = true;

      # We use LUKS for disk encryption, so ZFS does not need separate credentials.
      requestEncryptionCredentials = false;
    };
  };

  # ZFS Maintenance Services
  services.zfs = {
    # Perform a weekly scrub to detect and repair silent data corruption.
    autoScrub.enable = true;

    # Automated Snapshot Management
    # Snapshots are instantaneous and allow for easy system rollbacks.
    autoSnapshot = {
      enable = true;
      frequent = 8; # Every 15 minutes (keep 8)
      hourly = 24; # Every hour (keep 24)
      daily = 7; # Every day (keep 7)
      weekly = 4; # Every week (keep 4)
      monthly = 1; # Every month (keep 1)
    };
  };
}
