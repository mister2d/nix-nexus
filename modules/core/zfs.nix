_: {
  flake.modules.nixos.core-zfs =
    {
      lib,
      config,
      ...
    }:
    let
      cfg = config.nix-nexus.zfs;
    in
    {
      options.nix-nexus.zfs = {
        arcMax = lib.mkOption {
          type = lib.types.int;
          default = 4294967296; # 4GB
          description = "Maximum ZFS ARC size in bytes.";
        };
        arcMin = lib.mkOption {
          type = lib.types.int;
          default = 1073741824; # 1GB
          description = "Minimum ZFS ARC size in bytes.";
        };
        arcSysFree = lib.mkOption {
          type = lib.types.int;
          default = 2147483648; # 2GB
          description = "Memory to leave free for the system (outside ARC) in bytes.";
        };
        metaLimitPercent = lib.mkOption {
          type = lib.types.int;
          default = 75;
          description = "Maximum percentage of ARC that can be used for metadata.";
        };
        dnodeLimitPercent = lib.mkOption {
          type = lib.types.int;
          default = 10;
          description = "Maximum percentage of ARC that can be used for dnodes.";
        };
      };

      config = {
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
            # Limit ZFS ARC to prevent competition with application RAM.
            options zfs zfs_arc_max=${toString cfg.arcMax}
            options zfs zfs_arc_min=${toString cfg.arcMin}

            # Ensure ZFS leaves enough system memory free for kernel and userspace.
            options zfs zfs_arc_sys_free=${toString cfg.arcSysFree}

            # Metadata tuning for coding/build workloads (many small files).
            options zfs zfs_arc_meta_limit_percent=${toString cfg.metaLimitPercent}
            options zfs zfs_arc_dnode_limit_percent=${toString cfg.dnodeLimitPercent}

            # Workstation Responsiveness: Throttling background tasks
            # Limit the number of concurrent I/O operations for background tasks (scrub/trim)
            # to ensure user/application I/O always takes precedence.
            options zfs zfs_vdev_scrub_min_active=1
            options zfs zfs_vdev_scrub_max_active=2
            options zfs zfs_vdev_async_write_active_max_dirty_percent=60
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
      };
    };
}
