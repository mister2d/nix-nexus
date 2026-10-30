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
      # Hash files of the named tokens. Readable by the service user by path
      # (not through LoadCredential), so the directory is not under credsDir.
      tokensDir = "/var/lib/pi-durable-tokens";

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

      services = {
        pi-durable = {
          enable = true;
          vault.addr = "https://vault.service.consul:8200";

          instances.pi = {
            model = {
              provider = "gateway";
              name = "radiance/Qwen3.8";
              # Same id as the agent model: radiance/Qwen3.8 aliases it, and a
              # distinct id would make llama-swap unload and reload the model.
              subagentName = "radiance/Qwen3.8";
            };

            # Node ignores the system CA store. This bundle includes
            # certs/int_cert.crt (intermediate and root) via
            # security.pki.certificateFiles in core-security.
            caBundleFile = "/etc/ssl/certs/ca-certificates.crt";

            gateway.baseUrl = "https://inference.home.lan";

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

            # Named tokens. The files hold sha256 hashes only; the token texts stay
            # in /root/pi-durable-tokens. Add or remove tokens by editing the
            # files and running systemctl reload pi-durable-pi (SIGHUP).
            tokens = {
              r4b-viewer = {
                role = "viewer";
                hashFile = "${tokensDir}/r4b-viewer.sha256";
              };
              r4b-operator = {
                role = "operator";
                hashFile = "${tokensDir}/r4b-operator.sha256";
              };
              # Held by pi-durable-trigger-ops; its conversations are read-only.
              r4b-trigger = {
                role = "operator";
                hashFile = "${tokensDir}/r4b-trigger.sha256";
              };
              # An agent-kind approver: it must not decide high-risk requests.
              r4b-agent = {
                role = "operator";
                approver = "agent";
                hashFile = "${tokensDir}/r4b-agent.sha256";
              };
            };

            credentials = {
              roleIdFile = "${credsDir}/role_id";
              secretIdFile = "/run/credstore-unsealed/pidurable-secret-id";
              databaseUrlFile = "${credsDir}/database_url";
              inherit socketTokenFile;
            };
          };
        };

        # Browser bridge for the instance. The unified edge (bifrost-front-door) is its only client; the
        # loopback origin stays for tests through an ssh forward.
        pi-durable-web = {
          enable = true;
          bridges.pi = {
            listen = {
              address = "127.0.0.1";
              port = 8787;
            };
            allowedOrigins = [
              "https://pi.home.lan"
              "http://127.0.0.1:8787"
            ];
            trustProxy = true;
          };
        };

        # Webhook source "alerts": signed JSON events start read-only
        # conversations on the instance. Secret and token files live outside
        # the store (provisioned by hand, root only).
        pi-durable-trigger = {
          enable = true;
          services.ops = {
            target = {
              harness = "pi";
              tokenFile = "/root/pi-durable-tokens/trigger.token";
            };
            webhooks.alerts = {
              secretFile = "/root/pi-durable-tokens/hook_alerts.secret";
              fields = {
                message = "message";
                id = "id";
              };
              eventIdPath = "id";
              template = "Ops event {{id}}: {{message}}. Reply with one short sentence that acknowledges it. Use no tools.";
            };
          };
        };
        # TLS for pi.home.lan comes from the unified edge (services-bifrost-front-door),
        # which replaced pi-durable-haproxy and its Node renewer on petunia.
      };

      nix-nexus.secrets.credstore.unseal.pidurable-secret-id.consumers = [
        "pi-durable-pi.service"
      ];

      systemd = {
        tmpfiles.rules = [
          "d ${credsDir} 0700 root root -"
          "d ${tokensDir} 0750 root pdh-pi -"
          # Non-secret URL; the user and password come from Vault database/creds.
          "f ${credsDir}/database_url 0600 root root - postgresql://pidurable-db.service.consul:5432/pidurable?sslmode=verify-full&sslnegotiation=direct"
          # AppRole role_id of pidurable-pi: a Terraform output of vault-config,
          # not a secret (the secret_id is the credential). "f+" rewrites the
          # file on every activation so a changed value takes effect; update
          # this value if the role is recreated.
          "f+ ${credsDir}/role_id 0600 root root - 0856cc2e-a616-90cf-fad1-f27e1f53dddc"
        ];

        services = {
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
