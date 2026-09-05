# Registry key: flake.modules.nixos.core-sops
# Configures: sops-nix decryption using an age key derived from the host SSH key.
# Imported by: profiles/server/default.nix (server-default), profiles/workstation/default.nix (workstation-default).
# Options: nix-nexus.secrets.sops.hostFile
_: {
  flake.modules.nixos.core-sops =
    { lib, config, ... }:
    let
      cfg = config.nix-nexus.secrets.sops;
    in
    {
      options.nix-nexus.secrets.sops = {
        hostFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Per-host SOPS file holding this machine's encrypted secrets.
            Null leaves sops-nix inert, so hosts that declare no secrets are unaffected.
          '';
        };
      };

      config = lib.mkIf (cfg.hostFile != null) {
        sops = {
          defaultSopsFile = cfg.hostFile;
          defaultSopsFormat = "yaml";
          # Decrypt with an age key derived from the host's SSH host key, so a
          # host needs no key material beyond what it already has.
          age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
          # age only.
          gnupg.sshKeyPaths = [ ];
        };
      };
    };
}
