# Bifrost HTTPS front door.
# Registry key: flake.modules.nixos.services-bifrost-front-door
# Imports the module from the nix-bifrost flake input and points the Vault
# AppRole credentials at the core-credstore directory. The files are sealed by
# hand with systemd-creds (--name=role_id / --name=secret_id, TPM2 PCR 0).
# See docs/petunia.md.
{ inputs, ... }:
{
  flake.modules.nixos.services-bifrost-front-door =
    { config, ... }:
    let
      credsDir = config.nix-nexus.secrets.credstore.dir;
    in
    {
      imports = [ inputs.nix-bifrost.nixosModules.bifrost-front-door ];

      services.bifrost-front-door = {
        enable = true;
        openFirewall = true;
        tls.vault.credentials = {
          roleIdEncryptedFile = "${credsDir}/bifrost-front-door.role_id";
          secretIdEncryptedFile = "${credsDir}/bifrost-front-door.secret_id";
        };
      };
    };
}
