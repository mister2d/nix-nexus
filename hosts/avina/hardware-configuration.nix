{
  lib,
  pkgs,
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

      # virtio_blk covers VirtIO Block devices (/dev/vda);
      # virtio_scsi covers VirtIO SCSI devices (/dev/sda).
      # Both are included since Proxmox disk controller type varies by config.
      availableKernelModules = [
        "ahci"
        "xhci_pci"
        "virtio_pci"
        "virtio_blk"
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

    # Pin to 6.12 LTS. Kernels 6.13 and 6.14 have an unresolved regression
    # where the EFI stub freezes at initrd load on QEMU/OVMF VMs.
    # Track: https://github.com/NixOS/nixpkgs/issues (search EFI stub initrd)
    kernelPackages = pkgs.linuxPackages_6_12;
  };

  # hostId must match hosts/avina/default.nix
  networking.hostId = "a6b7c8d9";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
