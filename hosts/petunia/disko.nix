{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_1TB_S7U5NJ0XB06359F";
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
            DISK_LUKS = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                # Disko uses LUKS2 by default.
                settings.allowDiscards = true;
                # Password is provided interactively during nixos-install or disko execution
                content = {
                  type = "zfs";
                  pool = "petunia";
                };
              };
            };
          };
        };
      };
    };
    zpool = {
      petunia = {
        type = "zpool";
        options = {
          ashift = "12";
          autotrim = "on";
        };
        rootFsOptions = {
          compression = "lz4";
          acltype = "posixacl";
          xattr = "sa";
          relatime = "on";
          mountpoint = "none";
        };
        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
            options.mountpoint = "legacy";
            postCreateHook = "zfs snapshot petunia/root@blank";
          };
          nix = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options.mountpoint = "legacy";
          };
          home = {
            type = "zfs_fs";
            mountpoint = "/home";
            options.mountpoint = "legacy";
          };
          var = {
            type = "zfs_fs";
            mountpoint = "/var";
            options.mountpoint = "legacy";
          };
          swap = {
            type = "zfs_volume";
            size = "66G";
            content = {
              type = "swap";
              randomEncryption = true;
            };
          };
        };
      };
    };
  };
}
