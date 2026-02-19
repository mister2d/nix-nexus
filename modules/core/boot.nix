{ pkgs, ... }:

{
  # Kernel and Boot Configuration
  boot = {
    # We use the standard stable kernel. ZFS maintains compatibility
    # with the latest LTS/Stable releases.
    kernelPackages = pkgs.linuxPackages;

    # General Kernel Parameters
    kernelParams = [
      "quiet"
      "splash"
      "mem_sleep_default=deep" # Standard preference for deep sleep (S3) over s2idle
    ];

    # Initrd Configuration
    # Using systemd-based initrd for a modern, unified boot process.
    initrd = {
      systemd.enable = true;

      # LUKS (Disk Encryption) Configuration
      luks.devices = {
        "crypted" = {
          device = "/dev/disk/by-partlabel/DISK_LUKS";
          allowDiscards = true; # Enable TRIM support for SSD longevity
          bypassWorkqueues = true; # Performance optimization for modern NVMe drives
        };
      };
    };

    # Bootloader Menu Timeout
    loader.timeout = 3;
  };
}
