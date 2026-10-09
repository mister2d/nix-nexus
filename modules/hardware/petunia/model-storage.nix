# Merged into: flake.modules.nixos.hardware-petunia
# Configures: XFS Hugging Face hub mount and periodic TRIM for petunia.
# Imported by: hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.hardware-petunia = _: {
    boot.supportedFilesystems = [ "xfs" ];

    fileSystems."/data/huggingface/hub" = {
      device = "/dev/disk/by-partuuid/3078e6ab-ae1d-40de-9b81-ae3435b680e6";
      fsType = "xfs";
      options = [
        "noatime"
        "nofail"
        "x-systemd.device-timeout=10s"
      ];
    };

    services.fstrim.enable = true;
  };
}
