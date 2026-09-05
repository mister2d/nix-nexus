# Registry key: flake.modules.nixos.core-groot
# Configures: the groot system user, shell, and SSH authorized keys.
# Imported by: hosts/avina/default.nix (avina-default), hosts/hermes/default.nix (hermes-default).
_: {
  flake.modules.nixos.core-groot =
    { pkgs, ... }:
    let
      keys = import ../../lib/authorized-keys.nix;
    in
    {
      users.users.groot = {
        isNormalUser = true;
        extraGroups = [ "kvm" ];
        shell = pkgs.bash;
        openssh.authorizedKeys.keys = keys.tpmPersonal;
      };
    };
}
