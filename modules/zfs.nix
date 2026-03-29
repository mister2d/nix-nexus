{
  lib,
  ...
}:
{

  den.aspects.zfs-aspect = lib.mkForce {
    nixos =
      { lib, config, ... }:
      let
        inherit (lib) mkOption types;
        inherit (builtins) toString;
        cfg = config.nix-nexus.zfs;
      in
      {
        options.nix-nexus.zfs = {
          arcMax = mkOption {
            type = types.int;
            default = 4294967296;
            description = "Maximum ZFS ARC size in bytes.";
          };
          arcMin = mkOption {
            type = types.int;
            default = 1073741824;
            description = "Minimum ZFS ARC size in bytes.";
          };
          arcSysFree = mkOption {
            type = types.int;
            default = 2147483648;
            description = "Memory to leave free for the system (outside ARC) in bytes.";
          };
          metaLimitPercent = mkOption {
            type = types.int;
            default = 75;
            description = "Maximum percentage of ARC that can be used for metadata.";
          };
          dnodeLimitPercent = mkOption {
            type = types.int;
            default = 10;
            description = "Maximum percentage of ARC that can be used for dnodes.";
          };
        };

        config = {
          boot = {
            supportedFilesystems = [ "zfs" ];
            initrd.kernelModules = [ "zfs" ];
            zfs = {
              forceImportRoot = true;
              devNodes = "/dev/mapper";
              requestEncryptionCredentials = false;
            };
            extraModprobeConfig = ''
              options zfs zfs_arc_max=${toString cfg.arcMax}
              options zfs zfs_arc_min=${toString cfg.arcMin}
              options zfs zfs_arc_sys_free=${toString cfg.arcSysFree}
              options zfs zfs_arc_meta_limit_percent=${toString cfg.metaLimitPercent}
              options zfs zfs_arc_dnode_limit_percent=${toString cfg.dnodeLimitPercent}
              options zfs zfs_vdev_scrub_min_active=1
              options zfs zfs_vdev_scrub_max_active=2
              options zfs zfs_vdev_async_write_active_max_dirty_percent=60
            '';
          };

          services.zfs = {
            autoScrub.enable = true;
            autoSnapshot = {
              enable = true;
              frequent = 8;
              hourly = 24;
              daily = 7;
              weekly = 4;
              monthly = 1;
            };
          };
        };
      };
  };
}
