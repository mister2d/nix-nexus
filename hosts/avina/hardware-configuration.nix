{
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  # not-detected.nix is the minimal hardware-scan stub. It does not enable
  # systemd initrd, qemu-guest, or any profile that could interfere with the
  # busybox initrd + ZFS boot chain on QEMU/OVMF.
  # (qemu-guest.nix enables boot.initrd.systemd by default, which causes an
  # EFI stub freeze at initrd load on OVMF; the guest agent is handled instead
  # by nix-nexus.virtualization.guestAgent.enable in hosts/avina/default.nix.)
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    # GRUB2 instead of systemd-boot.
    # systemd-boot passes the initrd to the kernel via the LINUX_EFI_INITRD_MEDIA_GUID
    # EFI protocol; this protocol is buggy on certain Proxmox OVMF builds and causes
    # the kernel EFI stub to freeze at "Loaded initrd from". GRUB loads the kernel
    # and initrd into memory itself and jumps directly to the kernel entry point,
    # bypassing the EFI stub initrd mechanism entirely.
    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot"; # matches disko.nix ESP mountpoint
      };
      grub = {
        enable = true;
        efiSupport = true;
        device = "nodev"; # EFI-only install; no MBR write
        zfsSupport = true; # allow GRUB to read ZFS for kernels/configs
      };
    };
    initrd = {
      # ZFS must be available in the initrd for pool import at boot.
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
    # Force import if HostID differs between installer and runtime.
    kernelParams = [ "zfsforce=1" ];

    # Pin to 6.12 LTS. Kernels 6.13 and 6.14 have an unresolved regression
    # where the EFI stub freezes at initrd load on QEMU/OVMF VMs.
    kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;
  };

  # hostId must match hosts/avina/default.nix
  networking.hostId = "a6b7c8d9";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
