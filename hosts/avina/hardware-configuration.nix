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
      # Disable systemd initrd for this host. The systemd initrd has a race
      # condition with ZFS where mount units fire before the pool import
      # service completes, causing an indefinite stall. The busybox initrd
      # sequences ZFS pool import correctly and is the right choice for a
      # headless VM with no TPM2/FIDO2/LUKS requirements.
      systemd.enable = lib.mkForce false;

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
  };

  # hostId must match hosts/avina/default.nix
  networking.hostId = "a6b7c8d9";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
