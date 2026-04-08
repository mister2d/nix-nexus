{ ... }:
{
  # ============================================================================
  # ZFS Aspect: Durable Long-Term Memory
  # ============================================================================

  den.aspects.zfs-aspect = {
    nixos = { ... }: {
      boot.supportedFilesystems = [ "zfs" ];
      services.zfs.autoScrub.enable = true;
      services.zfs.trim.enable = true;

      # Global tuning defaults
      boot.kernelParams = [ "zfs.zfs_arc_max=2147483648" ]; # 2GB default
    };
  };
}
