_: {
  flake.modules.nixos.core-sysctl =
    { lib, config, ... }:
    let
      swappiness = 10; # percent
      vfsCachePressure = 50; # percent
      minFreeKbytes = 262144; # KB
    in
    {
      boot.kernel.sysctl = lib.mkIf (!config.boot.isContainer) {
        "vm.swappiness" = swappiness;
        "vm.vfs_cache_pressure" = vfsCachePressure;
        "vm.min_free_kbytes" = minFreeKbytes;
      };

      services.earlyoom = {
        enable = true;
        freeMemThreshold = 5;
        freeSwapThreshold = 10;
      };
    };
}
