# Registry key: flake.modules.nixos.core-credstore
# Configures: a root-only directory for TPM2-sealed systemd credentials and a self-test unit.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
# Options: nix-nexus.secrets.credstore.*
# The module holds no secret material. Sealing is a root-run runbook (seal-credential,
# docs/pi-durable-host.md). PID 1 unseals at unit start via LoadCredentialEncrypted=, so the
# consuming service needs no TPM device access. Services that cannot use LoadCredentialEncrypted= get
# their credential through a root-run unseal unit that writes a tmpfs file (nix-nexus.secrets.credstore.unseal).
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

      unsealDir = "/run/credstore-unsealed";

      unsealScript =
        name: u:
        pkgs.writeShellScript "credstore-unseal-${name}" ''
          set -eu
          umask 077
          tmp="$(${pkgs.coreutils}/bin/mktemp -p ${unsealDir} ".unseal.XXXXXX")"
          trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
          ${creds} decrypt --name=${lib.escapeShellArg u.credentialName} ${lib.escapeShellArg u.blob} "$tmp"
          ${pkgs.coreutils}/bin/mv "$tmp" ${unsealDir}/${lib.escapeShellArg name}
          trap - EXIT
        '';

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

        unseal = lib.mkOption {
          default = { };
          description = ''
            Credentials unsealed by a root-run oneshot into ${unsealDir}/<name> for services that read plain
            files. Each entry defines credstore-unseal-<name>.service.
          '';
          type = lib.types.attrsOf (
            lib.types.submodule (
              { name, ... }:
              {
                options = {
                  blob = lib.mkOption {
                    type = lib.types.path;
                    default = "${cfg.dir}/${name}";
                    defaultText = lib.literalExpression ''"''${config.nix-nexus.secrets.credstore.dir}/<name>"'';
                    description = "Sealed blob to decrypt.";
                  };
                  credentialName = lib.mkOption {
                    type = lib.types.str;
                    default = name;
                    description = "Name the blob was sealed under; must equal the blob file name (seal-credential NAME).";
                  };
                  consumers = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    example = [ "pi-durable-pi.service" ];
                    description = "Units that require this credential. They start after it and restart with it.";
                  };
                };
              }
            )
          );
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
        assertions = lib.mapAttrsToList (name: u: {
          assertion = u.credentialName == baseNameOf u.blob;
          message = "nix-nexus.secrets.credstore.unseal.${name}: credentialName must equal the blob file name, as seal-credential uses NAME for both.";
        }) cfg.unseal;

        systemd.tmpfiles.rules = [
          "d ${cfg.dir} 0700 root root -"
        ]
        ++ lib.optional (cfg.unseal != { }) "d ${unsealDir} 0700 root root -";

        environment.systemPackages = [ sealCredential ];

        systemd.services = lib.mkMerge [
          {
            credstore-selftest = lib.mkIf cfg.selfTest.enable {
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
          }

          (lib.mapAttrs' (
            name: u:
            lib.nameValuePair "credstore-unseal-${name}" {
              description = "Unseal TPM2 credential ${name}";
              partOf = u.consumers;
              unitConfig.ConditionPathExists = u.blob;
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = unsealScript name u;
                ExecStop = "${pkgs.coreutils}/bin/rm -f ${unsealDir}/${lib.escapeShellArg name}";
                NoNewPrivileges = true;
                ProtectSystem = "strict";
                ReadWritePaths = [ unsealDir ];
                ProtectHome = true;
                PrivateTmp = true;
                CapabilityBoundingSet = "";
              };
            }
          ) cfg.unseal)

          (lib.mkMerge (
            lib.mapAttrsToList (
              name: u:
              lib.genAttrs' u.consumers (
                consumer:
                lib.nameValuePair (lib.removeSuffix ".service" consumer) {
                  requires = [ "credstore-unseal-${name}.service" ];
                  after = [ "credstore-unseal-${name}.service" ];
                }
              )
            ) cfg.unseal
          ))
        ];
      };
    };
}
