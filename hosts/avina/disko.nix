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
          # Specialized dataset for PostgreSQL — optimized for snapshots/shipping
          postgresql = {
            type = "zfs_fs";
            mountpoint = "/var/lib/postgresql";
            options = {
              mountpoint = "legacy";
              recordsize = "128k";
            };
          };
          # Specialized dataset for Matrix Synapse (Media & State)
          matrix-synapse = {
            type = "zfs_fs";
            mountpoint = "/var/lib/matrix-synapse";
            options = {
              mountpoint = "legacy";
              recordsize = "128k";
            };
          };
          # Specialized dataset for MAS (State)
          matrix-authentication-service = {
            type = "zfs_fs";
            mountpoint = "/var/lib/matrix-authentication-service";
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
              randomEncryption = false; # No LUKS outer layer, simple swap
            };
          };
        };
      };
    };
  };
}
