# Registry key: flake.modules.nixos.core-users
# Configures: the ddukes system user, groups, shell, and SSH authorized keys.
# Imported by: profiles/server/default.nix (server-default), profiles/workstation/default.nix (workstation-default).
_: {
  flake.modules.nixos.core-users =
    { pkgs, ... }:
    {
      users.users.ddukes = {
        isNormalUser = true;
        description = "ddukes";
        password = "nixos";

        extraGroups = [
          "networkmanager"
          "wheel"
          "video"
          "audio"
          "input"
          "docker"
          "fuse"
          "render"
          "kvm"
        ];

        shell = pkgs.bash;

        openssh.authorizedKeys.keys = (import ../../lib/authorized-keys.nix).tpmPersonal;
      };
    };
}
