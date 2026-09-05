# Registry key: flake.modules.nixos.core-boot
# Configures: kernel packages, LUKS initrd unlock, and boot loader timeout.
# Imported by: profiles/workstation/default.nix (workstation-default).
_: {
  flake.modules.nixos.core-boot =
    {
      pkgs,
      lib,
      ...
    }:
    {
      boot = {
        kernelPackages = lib.mkDefault pkgs.linuxPackages;

        initrd = {
          systemd.enable = lib.mkDefault true;

          luks.devices = {
            "crypted" = {
              device = lib.mkDefault "/dev/disk/by-partlabel/DISK_LUKS";
              allowDiscards = true;
              bypassWorkqueues = true;
            };
          };
        };

        loader.timeout = 3;
      };
    };
}
