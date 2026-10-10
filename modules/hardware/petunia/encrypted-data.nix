# Merged into: flake.modules.nixos.hardware-petunia
# Configures: LUKS2 volume "data" (TPM2 unseal in stage 2) and the XFS /data mount for petunia.
# Imported by: hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.hardware-petunia = _: {
    # Stage 2 unlock: systemd-cryptsetup-generator reads /etc/crypttab. A failed
    # unseal (nofail, headless) never blocks boot and never touches the root pool.
    # No key file: the TPM2 token in the LUKS2 header (keyslot 1) unseals the volume.
    environment.etc.crypttab.text = ''
      data /dev/disk/by-partuuid/3078e6ab-ae1d-40de-9b81-ae3435b680e6 none tpm2-device=auto,headless=true,nofail,discard,no-read-workqueue,no-write-workqueue,x-systemd.device-timeout=10s
    '';

    fileSystems."/data" = {
      device = "/dev/mapper/data";
      fsType = "xfs";
      options = [
        "noatime"
        "nofail"
        "x-systemd.device-timeout=10s"
      ];
    };
  };
}
