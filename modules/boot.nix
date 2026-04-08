{ ... }:
{
  # ============================================================================
  # Boot Aspect: Hardware Initialization & Kernel Interface
  # ============================================================================

  den.aspects.boot-aspect = {
    nixos = { lib, pkgs, ... }: {
      boot = {
        kernelPackages = lib.mkDefault pkgs.linuxPackages;
        initrd = {
          systemd.enable = lib.mkDefault true;
          luks.devices."crypted" = {
            device = lib.mkDefault "/dev/disk/by-partlabel/DISK_LUKS";
            allowDiscards = true;
            bypassWorkqueues = true;
          };
        };
        loader.timeout = lib.mkDefault 3;
      };
    };
  };
}
