# pi-durable harness instance "pi".
# Registry key: modules.nixos.services-pi-durable
# Imports the module from the pi-durable flake input and supplies the host
# side: credential directory, tokens and secrets from sops, unseal bridge entry.
# The instance uses the gateway provider (bifrost on petunia) with MCP gateway tools and the decision layer.
# The execution guest is started by hand; guest.unit stays unset.
# See docs/pi-durable-host.md.
{ inputs, ... }:
{
  modules.nixos.services-pi-durable =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      credsDir = "/var/lib/pi-durable-creds";
      # Hash files of the named tokens. Readable by the service user by path
      # (not through LoadCredential), so the directory is not under credsDir.
      tokensDir = "/var/lib/pi-durable-tokens";

      # Decision learning trainer (pi-durable#143, D-156, D-158): the GPU host
      # dualie. groot's authorized_keys there forces decision-trainer-remote for
      # this key (from 10.0.1.25 only, restrict), so the command has no remote
      # part. The key is sealed in the credstore (pidurable-trainer-key).
      dualieKnownHosts = pkgs.writeText "pi-durable-dualie-known-hosts" ''
        dualie.home.lan ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB2/ukCHXkw4HDASa+AeN7UHhdJqfaR8Ph1jqH+f8k3D
      '';

      # Named tokens and what they may do. Every value lives in sops
      # (secrets/petunia.yaml, see docs/pi-durable-host.md "Tokens and
      # secrets"); scripts/pi-durable-token makes and rotates them. A name
      # added here needs its hash in the host file first: the build checks
      # that every declared key exists.
      namedTokens = {
        r4b-viewer.role = "viewer";
        r4b-operator.role = "operator";
        # Purges sessions.
        r4b-admin.role = "admin";
        # Held by pi-durable-trigger-ops (its text is pi-durable/trigger-token).
        r4b-trigger = {
          role = "operator";
          agent = true;
        };
        # Agent token: cannot set yolo or answer an ask.
        r4b-agent = {
          role = "operator";
          agent = true;
        };
      };
      hashKey = name: "pi-durable/token-hashes/${name}";
      secretPath = key: config.sops.secrets.${key}.path;
      ntfyTopic = "https://ntfy.service.internal.novuscotia.com/pi-durable";

      # The slot count lives in four places. Each must give the same number,
      # or a factory gets a slot that has no account, no role or no share.
      slotCounts =
        let
          tfvars = builtins.readFile "${inputs.vault-config}/terraform/homelab.tfvars";
          tfMatch = builtins.match ".*\ndurable_factory_slots *= *([0-9]+)\n.*" "\n${tfvars}\n";
        in
        {
          "pi-durable slots.count" = config.services.pi-durable.instances.pi.slots.count;
          "nix-permafrost guest default (permafrost.slots.count)" =
            (import "${inputs.nix-permafrost}/modules/_lib/slots.nix").defaults.count;
          "host workspaces count (permafrost.host.workspaces.count)" =
            config.permafrost.host.workspaces.count or null;
          "vault-config durable_factory_slots (terraform/homelab.tfvars)" =
            if tfMatch == null then null else lib.toInt (builtins.head tfMatch);
        };
    in
    {
      imports = [ inputs.pi-durable.nixosModules.default ];

      assertions = [
        {
          assertion = lib.length (lib.unique (lib.attrValues slotCounts)) == 1;
          message = "The factory slot counts differ: ${
            lib.concatStringsSep ", " (lib.mapAttrsToList (k: v: "${k} = ${toString v}") slotCounts)
          }. Make them equal (pi-durable#133).";
        }
      ];

      services = {
        pi-durable = {
          enable = true;
          vault.addr = "https://vault.service.consul:8200";

          instances.pi = {
            model = {
              provider = "gateway";
              name = "radiance/Qwen3.8";
              # Same id as the agent model. The radiance fleet resolves an alias
              # to the same entry and does not reload the model, but one id keeps
              # one catalog entry and one tool-support check.
              subagentName = "radiance/Qwen3.8";
            };

            # Node ignores the system CA store. This bundle includes
            # certs/int_cert.crt (intermediate and root) via
            # security.pki.certificateFiles in core-security.
            caBundleFile = "/etc/ssl/certs/ca-certificates.crt";

            gateway.baseUrl = "https://inference.home.lan";
            # The default output cap is 16384 tokens, and the thinking counts against it.
            # One large file in one write needs more (pi-durable#82).
            gateway.overrides = {
              "radiance/Qwen3.8".maxTokens = 65536;
              "radiance/Qwen3.8-Flash-Next".maxTokens = 65536;
              # Test price (pi-durable#72, D-147). Models here cost 0, so a daily
              # dollar budget never trips. The front door maps this name to the
              # same local model as radiance/Qwen3.8 (no swap, real cost 0), and
              # only the live check of the budget stop uses it. Never point a real
              # session or the agent model at this name.
              "radiance/claude-haiku-4-5".cost = {
                input = 10;
                output = 40;
              };
            };

            decisions = {
              # Enforce (owner, 2026-11-20): a deny blocks the call, and an unsure
              # verdict asks a person, so decision notices with their buttons reach
              # the phone (pi-durable D-178, D-185). The owner evaluates this over
              # time. "passive" records the verdicts but runs every call and asks
              # nobody.
              enforcement = "enforce";

              # Keep each decision as an eval case (D-77): the dataset for the
              # automatic threshold calibration (pi-durable#130, stage S0). Two years:
              # a case must outlive labeling and the collection gate of a fine-tune
              # (pi-durable#137, D-148), which can take months.
              evalCases = {
                enable = true;
                retentionDays = 730;
              };

              # Decision learning, stage 2 (pi-durable#139, D-152): once a day from
              # 03:00 UTC the harness labels the new eval cases with the qualified
              # local judge (radiance/Qwen3.8, rubric r3) and writes the collection
              # gate report. Labels stay in the state directory; nothing is trained.
              learning = {
                enable = true;
                # Each cycle checks the trainer with a status request (D-158); a
                # training run waits for the collection gate.
                trainer.command = [
                  "${pkgs.openssh}/bin/ssh"
                  "-i"
                  "/run/credentials/pi-durable-pi.service/trainer_key"
                  "-o"
                  "IdentitiesOnly=yes"
                  "-o"
                  "BatchMode=yes"
                  "-o"
                  "ConnectTimeout=20"
                  "-o"
                  "UserKnownHostsFile=${dualieKnownHosts}"
                  "groot@dualie.home.lan"
                ];
                # The rubric factory (D-157) uses the local agent model, so no
                # deployment case leaves the LAN (D-145).
                rubricFactory.model = "radiance/Qwen3.8";
              };
            };

            # The gateway is ours: its MCP skills load without an ask (Gitea #39).
            # Other servers still ask a person for each skill.
            mcp.skills.trustedServers = [ "inference.home.lan" ];

            # Runtime crons (D-41): an agent proposes, only a person accepts. The
            # trigger service below fires the accepted ones. Defaults: at most 10,
            # one run open at a time, an hour between runs, 5 USD per run.
            crons.runtime.enable = true;

            database.credsPath = "database/creds/pidurable-pi-owner";

            ssh = {
              host = "192.168.33.10";
              knownHosts = null;
              # Own guest account, not `agent`: it holds no sign-in files of the
              # owner's other harnesses. Its home is ephemeral (no virtiofs share,
              # nothing under /mnt/persist), so everything it writes is gone when
              # the VM stops. The Vault role signs principal adurable.
              user = "adurable";
              cwd = "/home/adurable/work";
              signPath = "ssh-client-signer/sign/durable";
            };

            workspaces.root = "/home/adurable/workspaces";

            # The work directory on the guest becomes a git repository (the files
            # already there go into a first commit), so the web client's Changes
            # view shows git diffs and per-file Revert works.
            workspace.gitInit = true;

            # Factories on repositories (pi-durable#131). The push token is read
            # from Vault KV with the instance AppRole at each push; no copy on
            # disk. Grants stay off (reach.grants.enable): the owner turns them on.
            reach.push = {
              hosts = [ "code.novuscotia.com" ];
              vaultKv = {
                mount = "kv-v2";
                path = "infrastructure/ai-ml/pi-durable/gitea";
                key = "token";
              };
            };
            factory = {
              gitHosts = [ "code.novuscotia.com" ];
              publish = {
                orgs = [ "novuscotia-ops" ];
                mergers = [ "ddukes" ];
              };
            };

            # Many factories (pi-durable#133): each factory works as its own guest
            # account f-slotN, with its own home and network profile. The count
            # (default 16) must equal the guest and vault-config; see the
            # assertion below. Only the trigger service token may name the cron
            # that starts a run (loop on create).
            slots = {
              enable = true;
              triggerTokens = [ "r4b-trigger" ];
              # The ops webhook below is no factory work: its runs keep the
              # base account (adurable) and hold no factory authority.
              triggers.alerts = null;
            };

            # Uploaded files on the guest: swept every 6 hours, removed after
            # 30 days, and at once when their session is purged.
            uploads.retainDays = 30;

            # The hash files are sops secrets linked into tokensDir. A rotated
            # hash reloads the harness (SIGHUP); a new name restarts it.
            tokens = lib.mapAttrs (name: t: t // { hashFile = secretPath (hashKey name); }) namedTokens;

            credentials = {
              roleIdFile = "${credsDir}/role_id";
              secretIdFile = "/run/credstore-unsealed/pidurable-secret-id";
              databaseUrlFile = "${credsDir}/database_url";
              socketTokenFile = secretPath "pi-durable/socket-token";
            };
            extraCredentials.trainer_key = "/run/credstore-unsealed/pidurable-trainer-key";

            # The owner signs in on the phone with the operator token: an
            # operator person may change the default budget and the breach
            # action, and make the approval rules stricter. Looser rules and
            # the decision timeout stay with an admin (pi-durable D-174, D-175).
            policyOperatorEdit = [
              "spend"
              "tighten"
            ];

            # Phone notices through the ntfy server (Nomad job ntfy). The user
            # pi-durable may only publish to the topic pi-durable; its token is
            # in sops (pi-durable/ntfy-token) and reaches the unit as the
            # credential notify_ntfy. A tap opens the session in the web client.
            notify = {
              publicUrl = "https://pi.home.lan";
              sinks.ntfy = {
                url = ntfyTopic;
                kind = "ntfy";
                events = [
                  "decision-ask"
                  "verdict"
                  "attention"
                ];
                tokenFile = secretPath "pi-durable/ntfy-token";
              };
            };
          };
        };

        # Browser bridge for the instance. The unified edge (bifrost-front-door) is its only client; the
        # loopback origin stays for tests through an ssh forward.
        pi-durable-web = {
          enable = true;
          pictureOrigins = [ "https://pictures.home.lan" ];
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

        # Webhook source "alerts": signed JSON events start
        # conversations in auto mode under an agent token. The token and the
        # webhook secret come from sops.
        pi-durable-trigger = {
          enable = true;
          services.ops = {
            target = {
              harness = "pi";
              tokenFile = secretPath "pi-durable/trigger-token";
              tokenName = "r4b-trigger";
            };
            runtimeCrons.enable = true;
            notify = {
              publicUrl = "https://pi.home.lan";
              sinks.ntfy = {
                url = ntfyTopic;
                kind = "ntfy";
                events = [ "run-finished" ];
                tokenFile = secretPath "pi-durable/ntfy-token";
              };
            };
            webhooks.alerts = {
              secretFile = secretPath "pi-durable/hook-alerts-secret";
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

      # The tokens and secrets of the instance. Paths outside /run/secrets for
      # the files the harness or pi-durable-attach read by path: they refuse a
      # file whose directory other users can enter, and /run/secrets.d is 0751.
      # The trigger service reads its files through LoadCredential.
      sops.secrets =
        lib.mapAttrs' (
          name: _:
          lib.nameValuePair (hashKey name) {
            path = "${tokensDir}/${name}.sha256";
            group = "pdh-pi";
            mode = "0440";
            reloadUnits = [ "pi-durable-pi.service" ];
          }
        ) namedTokens
        // {
          # The legacy admin token of the socket. Members of pdh-pi may read
          # it; that group already opens the socket.
          "pi-durable/socket-token" = {
            path = "${credsDir}/socket_token";
            group = "pdh-pi";
            mode = "0440";
            restartUnits = [ "pi-durable-pi.service" ];
          };
          "pi-durable/trigger-token".restartUnits = [ "pi-durable-trigger-ops.service" ];
          "pi-durable/hook-alerts-secret".restartUnits = [ "pi-durable-trigger-ops.service" ];
          # Read by systemd as root (LoadCredential notify_ntfy) for both units.
          "pi-durable/ntfy-token".restartUnits = [
            "pi-durable-pi.service"
            "pi-durable-trigger-ops.service"
          ];
        };

      nix-nexus.secrets.credstore.unseal = {
        pidurable-secret-id.consumers = [ "pi-durable-pi.service" ];
        pidurable-trainer-key.consumers = [ "pi-durable-pi.service" ];
      };

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
          # The harness reads the model catalog and the MCP tool list through
          # the edge (https://inference.home.lan) when it starts, and sends
          # decisions through it; start it after the edge.
          pi-durable-pi = {
            after = [
              "bifrost-front-door.service"
              "sops-install-secrets.service"
            ];
            wants = [ "bifrost-front-door.service" ];
          };
          pi-durable-trigger-ops.after = [ "sops-install-secrets.service" ];
        };
      };
    };
}
