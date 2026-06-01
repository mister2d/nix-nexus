_: {
  flake.modules.nixos.core-sysctl =
    { lib, config, ... }:
    {
      boot.kernel.sysctl = lib.mkIf (!config.boot.isContainer) {
        "vm.swappiness" = 10;
        "vm.vfs_cache_pressure" = 50;
        "vm.min_free_kbytes" = 262144;
      };

      services.earlyoom = {
        enable = true;
        freeMemThreshold = 5;
        freeSwapThreshold = 10;
      };
    };
}
