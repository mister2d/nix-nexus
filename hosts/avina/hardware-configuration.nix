{
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    initrd = {
      # Ensure ZFS is available early in the boot process
      supportedFilesystems = [ "zfs" ];
      availableKernelModules = [
        "ahci"
        "xhci_pci"
        "virtio_pci"
        "virtio_scsi"
        "sd_mod"
        "sr_mod"
      ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
    # Force import if HostID differs between installer and runtime
    kernelParams = [ "zfsforce=1" ];
  };

  # hostId must match hosts/avina/default.nix
  networking.hostId = "a6b7c8d9";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
