_: {
  den.aspects.hw-petunia-aspect = {
    nixos =
      {
        config,
        ...
      }:
      {
        boot = {
          kernelModules = [
            "kvm-amd"
            "nvidia"
            "nvidia_modeset"
            "nvidia_uvm"
            "nvidia_drm"
          ];
          initrd.availableKernelModules = [
            "nvme"
            "xhci_pci"
            "ahci"
            "usbhid"
            "usb_storage"
            "sd_mod"
          ];
        };

        hardware = {
          cpu.amd.updateMicrocode = true;
          enableRedistributableFirmware = true;
          graphics = {
            enable = true;
            enable32Bit = true;
          };
          nvidia = {
            modesetting.enable = true;
            powerManagement.enable = false;
            powerManagement.finegrained = false;
            open = false;
            nvidiaSettings = true;
            package = config.boot.kernelPackages.nvidiaPackages.stable;
          };
        };

        # GPU drivers
        services.xserver.videoDrivers = [ "nvidia" ];

        # Per-host storage
        fileSystems."/" = {
          device = "petunia/root";
          fsType = "zfs";
        };
        fileSystems."/boot" = {
          device = "/dev/disk/by-uuid/B93E-0676";
          fsType = "vfat";
        };
      };
  };
}
