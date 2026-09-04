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
