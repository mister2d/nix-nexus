# Registry key: flake.modules.nixos.core-sshd
# Configures: OpenSSH hardening and the trusted CA for certificate logins.
# Imported by: profiles/server/default.nix (server-default), profiles/workstation/default.nix (workstation-default).
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
