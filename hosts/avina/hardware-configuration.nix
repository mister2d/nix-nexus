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
      # Use GRUB for Legacy BIOS compatibility
      grub = {
        enable = true;
        devices = lib.mkForce [ "/dev/sda" ]; # Target install disk
        efiSupport = false; # Set to true only if using EFI
      };
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

  # Networking
  networking.useDHCP = lib.mkDefault true;
  networking.hostId = "a6b7c8d9"; # Must match hosts/avina/default.nix

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
