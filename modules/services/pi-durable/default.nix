# pi-durable harness instance "pi".
# Registry key: flake.modules.nixos.services-pi-durable
# Imports the module from the pi-durable flake input and supplies the host
# side: credential directory, socket token generator, unseal bridge entry.
# The execution guest is started by hand; guest.unit stays unset.
# See docs/pi-durable-host.md.
{ inputs, ... }:
{
  flake.modules.nixos.services-pi-durable =
    { pkgs, ... }:
    let
      credsDir = "/var/lib/pi-durable-creds";
      socketTokenFile = "${credsDir}/socket_token";

      generateSocketToken = pkgs.writeShellScript "pi-durable-socket-token" ''
        set -euo pipefail
        umask 077
        tmp="$(${pkgs.coreutils}/bin/mktemp ${credsDir}/.socket_token.XXXXXX)"
        ${pkgs.coreutils}/bin/head -c 32 /dev/urandom \
          | ${pkgs.coreutils}/bin/od -An -tx1 \
          | ${pkgs.coreutils}/bin/tr -d ' \n' > "$tmp"
        ${pkgs.coreutils}/bin/chown root:pdh-pi "$tmp"
        ${pkgs.coreutils}/bin/chmod 0640 "$tmp"
        ${pkgs.coreutils}/bin/mv "$tmp" ${socketTokenFile}
      '';
    in
    {
      imports = [ inputs.pi-durable.nixosModules.default ];

      services.pi-durable = {
        enable = true;
        vault.addr = "https://vault.service.consul:8200";

        instances.pi = {
          model = {
            provider = "anthropic";
            # Default pending confirmation of the intended model id.
            name = "claude-sonnet-5-5";
          };

          database.credsPath = "database/creds/pidurable-pi-owner";

          ssh = {
            host = "192.168.33.10";
            knownHosts = null;
            signPath = "ssh-client-signer/sign/agentrole";
          };

          credentials = {
            roleIdFile = "${credsDir}/role_id";
            secretIdFile = "/run/credstore-unsealed/pidurable-secret-id";
            databaseUrlFile = "${credsDir}/database_url";
            inherit socketTokenFile;
          };
        };
      };

      nix-nexus.secrets.credstore.unseal.pidurable-secret-id.consumers = [ "pi-durable-pi.service" ];

      systemd.tmpfiles.rules = [
        "d ${credsDir} 0700 root root -"
        # Non-secret URL; the user and password come from Vault database/creds.
        "f ${credsDir}/database_url 0600 root root - postgresql://pidurable-db.service.consul:5432/pidurable?sslmode=verify-full&sslnegotiation=direct"
      ];

      # Generated once on first start. root:pdh-pi 0640 lets members of the
      # socket group read the token they must present; that group already
      # grants access to the socket, so the read adds no authority. The
      # harness itself receives the token through LoadCredential.
      systemd.services.pi-durable-socket-token = {
        description = "Generate the pi-durable socket token";
        before = [ "pi-durable-pi.service" ];
        requiredBy = [ "pi-durable-pi.service" ];
        after = [ "systemd-tmpfiles-setup.service" ];
        unitConfig.ConditionPathExists = "!${socketTokenFile}";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = generateSocketToken;
        };
      };
    };
}
