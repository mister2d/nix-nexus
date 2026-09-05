# Host: petunia (NixOS x86_64 workstation).
# Registry key: flake.modules.nixos.petunia-disko
# Configures: ZFS-on-LUKS disk layout (root, nix, home, data, var datasets) via disko.
# Imported by: hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.petunia-disko = _: {
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
                  # Passphrase is collected by install.sh before disko runs and
                  # written to this path. Bypasses disko's interactive prompting,
                  # which has a variable-scoping bug (password: unbound variable).
                  passwordFile = "/tmp/disko-luks-password";
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
            atime = "off";
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
              options = {
                mountpoint = "legacy";
                atime = "off"; # Explicitly disable atime for the nix store
              };
            };
            home = {
              type = "zfs_fs";
              mountpoint = "/home";
              options = {
                mountpoint = "legacy";
                # Standard recordsize is good for general use and coding
                recordsize = "128k";
              };
            };
            # Specialized dataset for AI Models and Datasets (Large Files)
            data = {
              type = "zfs_fs";
              mountpoint = "/data";
              mountOptions = [ "nofail" ];
              options = {
                mountpoint = "legacy";
                # Optimized for large sequential reads (Model Weights, Datasets)
                recordsize = "1M";
                # Large models are often already compressed or incompressible (weights),
                # but lz4 handles this with negligible overhead.
                compression = "lz4";
              };
            };
            var = {
              type = "zfs_fs";
              mountpoint = "/var";
              options.mountpoint = "legacy";
            };
          };
        };
      };
    };
  };
}
