_: {
  flake.modules.nixos.core-sshd =
    { lib, ... }:
    {
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = lib.mkDefault "prohibit-password";
          TrustedUserCAKeys = "${../../certs/trusted_ssh_ca.pub}";
        };
      };
    };
}
