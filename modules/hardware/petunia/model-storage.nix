# Merged into: flake.modules.nixos.hardware-petunia
# Configures: XFS Hugging Face model mount and periodic TRIM for petunia.
# Imported by: hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.hardware-petunia = _: {
    boot.supportedFilesystems = [ "xfs" ];

    fileSystems."/data/huggingface/models" = {
      device = "/dev/disk/by-partuuid/6c85fb39-ac0c-41af-afd8-62416f155e40";
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
