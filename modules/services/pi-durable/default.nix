# pi-durable harness instance "pi".
# Registry key: flake.modules.nixos.services-pi-durable
# Imports the module from the pi-durable flake input and supplies the host
# side: credential directory, socket token generator, unseal bridge entry.
# The instance uses the gateway provider (bifrost on petunia) with image tools.
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
            provider = "gateway";
            name = "radiance/Qwen3.8-MXFP4";
            # Same id as the agent model: radiance/Qwen3.8 aliases it, and a
            # distinct id would make llama-swap unload and reload the model.
            subagentName = "radiance/Qwen3.8-MXFP4";
          };

          gateway.baseUrl = "http://petunia.home.lan:8080";

          images = {
            enable = true;
            recommendedChatModel = "radiance/Qwen3.8-Imagine-Turbo";
            defaultModel = "turbo";
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

      systemd = {
        tmpfiles.rules = [
          "d ${credsDir} 0700 root root -"
          # Non-secret URL; the user and password come from Vault database/creds.
          "f ${credsDir}/database_url 0600 root root - postgresql://pidurable-db.service.consul:5432/pidurable?sslmode=verify-full&sslnegotiation=direct"
          # AppRole role_id of pidurable-pi: a Terraform output of vault-config,
          # not a secret (the secret_id is the credential). "f+" rewrites the
          # file on every activation so a changed value takes effect; update
          # this value if the role is recreated.
          "f+ ${credsDir}/role_id 0600 root root - 0856cc2e-a616-90cf-fad1-f27e1f53dddc"
        ];

        services = {
          # Node ignores the system CA store. This bundle includes
          # certs/int_cert.crt (intermediate and root) via
          # security.pki.certificateFiles in core-security.
          pi-durable-pi.environment.NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/ca-certificates.crt";

          # Generated once on first start. root:pdh-pi 0640 lets members of the
          # socket group read the token they must present; that group already
          # grants access to the socket, so the read adds no authority. The
          # harness itself receives the token through LoadCredential.
          pi-durable-socket-token = {
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
      };
    };
}
