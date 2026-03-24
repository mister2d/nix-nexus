{
  pkgs,
  lib,
  ...
}:

{
  # Kernel and Boot Configuration
  boot = {
    # We use the standard stable kernel. ZFS maintains compatibility
    # with the latest LTS/Stable releases.
    kernelPackages = pkgs.linuxPackages;

    # Initrd Configuration
    # Using systemd-based initrd for a modern, unified boot process.
    initrd = {
      systemd.enable = true;

      # LUKS (Disk Encryption) Configuration
      luks.devices = {
        "crypted" = {
          # Use mkDefault to allow disko or host-specific overrides
          device = lib.mkDefault "/dev/disk/by-partlabel/DISK_LUKS";
          allowDiscards = true; # Enable TRIM support for SSD longevity
          bypassWorkqueues = true; # Performance optimization for modern NVMe drives
        };
      };
    };

    # Bootloader Menu Timeout
    loader.timeout = 3;
  };
}
