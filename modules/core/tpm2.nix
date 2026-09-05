# Registry key: flake.modules.nixos.core-tpm2
# Configures: TPM2 support for LUKS auto-unlock via systemd-cryptenroll.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
# Options: nix-nexus.tpm2.users
# See docs/secrets.md for per-host TPM2 enrollment posture.
_: {
  flake.modules.nixos.core-tpm2 =
    { config, lib, ... }:
    {
      options.nix-nexus.tpm2.users = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "ddukes" ];
        description = ''
          Users granted access to the TPM resource manager (/dev/tpmrm0) via
          membership in security.tpm2.tssGroup. Userspace TPM consumers such
          as ssh-tpm-agent and tpm2-pkcs11 require this membership. LUKS
          unsealing runs in initrd as root and needs no group membership.
        '';
      };

      config = {
        security.tpm2 = {
          enable = true;
          pkcs11.enable = true;
          tctiEnvironment.enable = true;
        };

        boot.initrd.systemd.tpm2.enable = true;

        # security.tpm2 already emits the udev rule granting tssGroup access to
        # /dev/tpmrm0, so membership is the whole mechanism.
        users.users = lib.genAttrs config.nix-nexus.tpm2.users (_: {
          extraGroups = [ config.security.tpm2.tssGroup ];
        });
      };
    };
}
