# Merged into: flake.modules.nixos.development-default
# Configures: the Docker daemon.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.development-default =
    { pkgs, ... }:
    {
      # Docker daemon is a system-wide service
      virtualisation.docker = {
        enable = true;
        package = pkgs.docker_29;
        storageDriver = "zfs";
      };
    };
}
