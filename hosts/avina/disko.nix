{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              priority = 1;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "fmask=0077"
                  "dmask=0077"
                ];
              };
            };
            zfs = {
              size = "100%";
              priority = 2;
              content = {
                type = "zfs";
                pool = "avina";
              };
            };
          };
        };
      };
    };
    zpool = {
      avina = {
        type = "zpool";
        options = {
          ashift = "12";
          autotrim = "on";
        };
        rootFsOptions = {
          compression = "lz4";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
          mountpoint = "none";
        };
        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options.mountpoint = "legacy";
          };
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              mountpoint = "legacy";
              atime = "off";
            };
          };
          var = {
            type = "zfs_fs";
            mountpoint = "/var";
            options.mountpoint = "legacy";
          };
          # Matrix Stack Persistence:
          # These datasets are isolated to enable atomic ZFS snapshots for
          # backup, restore, and data shipping of the entire communication stack.
          postgresql = {
            type = "zfs_fs";
            mountpoint = "/var/lib/postgresql";
            options = {
              mountpoint = "legacy";
              recordsize = "128k"; # Optimized for DB/Media balance
            };
          };
          matrix-synapse = {
            type = "zfs_fs";
            mountpoint = "/var/lib/matrix-synapse";
            options = {
              mountpoint = "legacy";
              recordsize = "128k";
            };
          };
          matrix-authentication-service = {
            type = "zfs_fs";
            mountpoint = "/var/lib/matrix-authentication-service";
            options = {
              mountpoint = "legacy";
              recordsize = "128k";
            };
          };
          # Persistent Bootstrap Secrets:
          # Stores the Vault AppRole credentials ("Master Key") required to
          # fetch all runtime secrets into RAM at boot.
          secrets = {
            type = "zfs_fs";
            mountpoint = "/var/lib/secrets";
            options = {
              mountpoint = "legacy";
              recordsize = "128k";
            };
          };
          swap = {
            type = "zfs_volume";
            size = "8G";
            content = {
              type = "swap";
              randomEncryption = false; # No LUKS outer layer on this host
            };
          };
        };
      };
    };
  };
}
