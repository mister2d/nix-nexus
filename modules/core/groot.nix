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
