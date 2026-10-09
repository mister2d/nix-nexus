# Registry key: flake.modules.nixos.core-zram-swap
# Configures: zstd zram swap and the matching vm.swappiness / vm.page-cluster sysctls.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.core-zram-swap =
    { lib, ... }:
    {
      zramSwap = {
        enable = true;
        algorithm = "zstd";
        memoryPercent = lib.mkDefault 50;
        priority = 100;
      };

      boot.kernel.sysctl = {
        # Priority 900 outranks the mkDefault 10 from core-sysctl.
        "vm.swappiness" = lib.mkOverride 900 100;
        "vm.page-cluster" = lib.mkDefault 0;
      };
    };
}
