# Registry key: flake.modules.nixos.core-credstore
# Configures: a root-only directory for TPM2-sealed systemd credentials and a self-test unit.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
# Options: nix-nexus.secrets.credstore.*
# The module holds no secret material. Sealing is a root-run runbook (seal-credential,
# docs/pi-durable-host.md). PID 1 unseals at unit start via LoadCredentialEncrypted=, so the
# consuming service needs no TPM device access.
_: {
  flake.modules.nixos.core-credstore =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.nix-nexus.secrets.credstore;
      creds = "${config.systemd.package}/bin/systemd-creds";
      pcrs = lib.concatMapStringsSep "+" toString cfg.tpm2Pcrs;

      sealCredential = pkgs.writeShellApplication {
        name = "seal-credential";
        text = ''
          # Usage: seal-credential NAME < plaintext
          # Seals stdin to the TPM2 under NAME and writes ${cfg.dir}/NAME.
          if [ "$#" -ne 1 ]; then
            echo "usage: seal-credential NAME < plaintext" >&2
            exit 2
          fi
          if [ "$(id -u)" -ne 0 ]; then
            echo "seal-credential must run as root" >&2
            exit 1
          fi
          name="$1"
          umask 077
          tmp="$(mktemp -p ${cfg.dir} ".sealing.XXXXXX")"
          trap 'rm -f "$tmp"' EXIT
          ${creds} encrypt --with-key=tpm2 --tpm2-pcrs=${pcrs} --name="$name" - "$tmp"
          mv "$tmp" "${cfg.dir}/$name"
          trap - EXIT
        '';
      };

      selfTest = pkgs.writeShellScript "credstore-selftest" ''
        set -eu
        if [ ! -s "$CREDENTIALS_DIRECTORY/selftest" ]; then
          echo "credstore-selftest: credential selftest not delivered" >&2
          exit 1
        fi
        echo "credstore-selftest: credential delivered"
        if ls /dev/tpm* >/dev/null 2>&1; then
          echo "credstore-selftest: TPM device visible inside unit" >&2
          exit 1
        fi
        echo "credstore-selftest: no TPM device visible"
      '';
    in
    {
      options.nix-nexus.secrets.credstore = {
        dir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/credstore.encrypted";
          description = ''
            Directory holding TPM2-sealed credential blobs. Units reference blobs by absolute path in
            LoadCredentialEncrypted=, because systemd's bare-name search path does not include this directory.
          '';
        };

        tpm2Pcrs = lib.mkOption {
          type = lib.types.listOf lib.types.ints.unsigned;
          default = [ 0 ];
          example = [ 7 ];
          description = ''
            PCR indices that seal-credential binds blobs to. systemd-creds binds no PCR unless told to.
          '';
        };

        selfTest.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Define credstore-selftest.service, a manually started unit. With PrivateDevices=yes it decrypts the
            sealed credential named selftest from the credstore directory and fails if any /dev/tpm* node is visible.
          '';
        };
      };

      config = {
        systemd.tmpfiles.rules = [ "d ${cfg.dir} 0700 root root -" ];

        environment.systemPackages = [ sealCredential ];

        systemd.services.credstore-selftest = lib.mkIf cfg.selfTest.enable {
          description = "TPM2-sealed credential delivery self-test";
          unitConfig.ConditionPathExists = "${cfg.dir}/selftest";
          serviceConfig = {
            Type = "oneshot";
            DynamicUser = true;
            PrivateDevices = true;
            LoadCredentialEncrypted = "selftest:${cfg.dir}/selftest";
            ExecStart = selfTest;
          };
        };
      };
    };
}
