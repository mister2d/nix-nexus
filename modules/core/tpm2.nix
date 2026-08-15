# TPM2 support for LUKS auto-unlock via systemd-cryptenroll.
#
# Opt in per host — avina and hermes are Proxmox LXC and have no TPM.
#
# Nothing here is host-specific: the PIN requirement lives in the enrollment
# command, not in this configuration. See docs/secrets.md for the per-host
# posture, which is NOT uniform:
#
#   petunia  plain PCR-0 auto-unseal — accepted risk, physically-controlled desktop
#   sweet16  MUST enroll --tpm2-with-pin=yes — laptop, theft is the threat model
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
          membership in security.tpm2.tssGroup. Required by userspace TPM
          consumers such as ssh-tpm-agent and tpm2-pkcs11; LUKS unsealing runs
          in initrd as root and needs nothing here.
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
