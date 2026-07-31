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
  flake.modules.nixos.core-tpm2 = _: {
    security.tpm2 = {
      enable = true;
      pkcs11.enable = true;
      tctiEnvironment.enable = true;
    };

    boot.initrd.systemd.tpm2.enable = true;
  };
}
