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

        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQp6H/n2JPSt1VxCAupTC1OTh7R3eu7wO0ZtCNbAkd7"
        ];
      };
    };
}
