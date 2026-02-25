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

      # Direct ZFS to scan /dev/mapper for the LUKS-unlocked device.
      # This prevents the import service from timing out while searching
      # for the 'cake' pool on the encrypted physical partitions.
      devNodes = "/dev/mapper";

      # We use LUKS for disk encryption, so ZFS does not need separate credentials.
      requestEncryptionCredentials = false;
    };

    # ZFS Performance and Memory Tuning
    extraModprobeConfig = ''
      # Limit ZFS ARC to 8GB to prevent competition with application RAM
      options zfs zfs_arc_max=8589934592
      # Ensure ZFS leaves at least 1GB of system memory free
      options zfs zfs_arc_sys_free=1073741824
    '';
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
