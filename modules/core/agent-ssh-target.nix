# Registry key: flake.modules.nixos.core-agent-ssh-target
# Configures: certificate-only, restricted SSH login for the agent identity.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
# The Vault SSH CA is trusted fleet-wide by core-sshd (TrustedUserCAKeys). This module adds a
# Match User agent block: principals come from /etc/ssh/authorized_principals.d/agent, authorized_keys
# files are ignored, and forwarding and tunnelling are off. The agent user is never in nix
# trusted-users, so it can import only signed store paths. Requires core-agent-identities.
_: {
  flake.modules.nixos.core-agent-ssh-target =
    { config, lib, ... }:
    let
      trusted = config.nix.settings.trusted-users;
    in
    {
      # A copied file (mode != symlink), not the default /etc/static symlink into /nix/store: sshd StrictModes
      # refuses a principals file whose resolved path crosses the group-writable /nix/store directory.
      environment.etc."ssh/authorized_principals.d/agent" = {
        mode = "0644";
        text = ''
          agent
        '';
      };

      services.openssh.extraConfig = lib.mkAfter ''
        Match User agent
          AuthorizedPrincipalsFile /etc/ssh/authorized_principals.d/%u
          AuthorizedKeysFile none
          AuthenticationMethods publickey
          PasswordAuthentication no
          AllowAgentForwarding no
          AllowTcpForwarding no
          AllowStreamLocalForwarding no
          X11Forwarding no
          PermitTunnel no
          PermitTTY yes
      '';

      assertions = [
        {
          assertion = config.services.openssh.enable;
          message = "core-agent-ssh-target requires services.openssh.enable (core-sshd).";
        }
        {
          assertion = !(builtins.elem "agent" trusted) && !(builtins.elem "@agent" trusted);
          message = "nix.settings.trusted-users must not contain the agent identity: trusted users are root-equivalent.";
        }
      ];
    };
}
