{
  pkgs,
  vaultAddr,
  certDomain,
  ...
}:
let
  certDir = "/run/certs";
  secretDir = "/run/secrets";
  persistentSecretDir = "/var/lib/secrets";

  # ── Vault KV-v2 Hierarchy ───────────────────────────────────────────────
  # The configuration is structured into three distinct tiers of truth:
  # 1. Config Tier (/config):  Global structural metadata (domains, names).
  # 2. Service Tier (/synapse): Cryptographic keys for the homeserver.
  # 3. Service Tier (/mas):     Cryptographic keys for the OIDC bridge.
  # ─────────────────────────────────────────────────────────────────────────
  matrixKvBase = "kv-v2/data/infrastructure/matrix/avina";
  configPath = "${matrixKvBase}/config";
  synapsePath = "${matrixKvBase}/synapse";
  masPath = "${matrixKvBase}/mas";

  # certDomain is the domain under which the TLS certificate is stored in
  # Vault KV. This is typically the root or wildcard domain (e.g.
  # novuscotia.com) and is independent of matrixDomain (matrix.novuscotia.com).
  kvPath = "kv-v2/data/letsencrypt/certificates/live/${certDomain}";
  smtpPath = "kv-v2/data/infrastructure/smtp";

  # ── Runtime Templates ───────────────────────────────────────────────────
  # Templates are rendered to RAM (/run) and never persist in the Nix store.

  haproxyTmpl = pkgs.writeText "haproxy-cert.ctmpl" ''
    {{ with secret "${kvPath}" }}
    {{ .Data.data.fullchain }}{{ .Data.data.privkey }}
    {{ end }}
  '';

  coturnCertTmpl = pkgs.writeText "coturn-cert.ctmpl" ''
    {{ with secret "${kvPath}" }}
    {{ .Data.data.fullchain }}
    {{ end }}
  '';

  coturnKeyTmpl = pkgs.writeText "coturn-key.ctmpl" ''
    {{ with secret "${kvPath}" }}
    {{ .Data.data.privkey }}
    {{ end }}
  '';

  # Synapse Identities and Keys:
  # Pulls structural identity from 'config' and cryptographic keys from 'synapse'.
  synapseSecretsTmpl = pkgs.writeText "synapse-secrets.ctmpl" ''
    {{ with $c := secret "${configPath}" }}
    {{ with $s := secret "${synapsePath}" }}
    server_name: "{{ $c.Data.data.matrix_domain }}"
    public_baseurl: "https://{{ $c.Data.data.matrix_domain }}"
    instance_name: "{{ $c.Data.data.instance_name }}"
    macaroon_secret_key: "{{ $s.Data.data.macaroon_secret_key }}"
    form_secret: "{{ $s.Data.data.form_secret }}"
    registration_shared_secret: "{{ $s.Data.data.registration_shared_secret }}"
    turn_shared_secret: "{{ $s.Data.data.turn_shared_secret }}"

    matrix_authentication_service:
      enabled: true
      issuer: "https://{{ $c.Data.data.auth_domain }}"
      client_id: "synapse"
      secret: "{{ $s.Data.data.mas_shared_secret }}"
    {{ end }}
    {{ end }}
  '';

  # Synapse Email Configuration:
  synapseEmailTmpl = pkgs.writeText "synapse-email.ctmpl" ''
    {{ with $smtp := secret "${smtpPath}" }}
    {{ with $c := secret "${configPath}" }}
    email:
      enable_notifs: true
      smtp_host: "smtp.mailgun.org"
      smtp_port: 587
      smtp_user: "postmaster@mg.{{ $c.Data.data.matrix_domain }}"
      smtp_pass: "{{ $smtp.Data.data.smtp_password }}"
      require_transport_security: true
      notif_from: "Matrix <noreply@{{ $c.Data.data.matrix_domain }}>"
    {{ end }}
    {{ end }}
  '';

  # MAS Configuration:
  masConfigTmpl = pkgs.writeText "mas-config.ctmpl" ''
    {{ with $c := secret "${configPath}" }}
    {{ with $m := secret "${masPath}" }}
    http:
      public_base: "https://{{ $c.Data.data.auth_domain }}"
      listeners:
        - name: web
          resources:
            - name: discovery
            - name: human
            - name: oauth
            - name: compat
            - name: graphql
            - name: assets
          binds: [{ host: "127.0.0.1", port: 8181 }]
    database:
      host: "/run/postgresql"
      database: "matrix-authentication-service"
      username: "matrix-authentication-service"
    secrets:
      encryption: "{{ $m.Data.data.encryption_key }}"
    upstream_oauth2:
      providers:
        - id: "01H75Z9682SZK6WEZKD98Z2YBP"
          issuer: "{{ $m.Data.data.oidc_issuer }}"
          client_id: "{{ $m.Data.data.oidc_client_id }}"
          client_secret: "{{ $m.Data.data.oidc_client_secret }}"
          token_endpoint_auth_method: "client_secret_basic"
    matrix:
      kind: synapse
      homeserver: "{{ $c.Data.data.matrix_domain }}"
      secret: "{{ $m.Data.data.mas_shared_secret }}"
      endpoint: "http://127.0.0.1:8008"
    {{ end }}
    {{ end }}
  '';

  coturnSecretTmpl = pkgs.writeText "coturn-secret.ctmpl" ''
    {{ with secret "${synapsePath}" }}{{ .Data.data.turn_shared_secret }}{{ end }}
  '';

  coturnSecretEnvTmpl = pkgs.writeText "coturn-env.ctmpl" ''
    {{ with secret "${synapsePath}" }}
    LIVEKIT_TURN_SHARED_SECRET={{ .Data.data.turn_shared_secret }}
    {{ end }}
  '';

  # ── Vault Agent Configuration ──────────────────────────────────────────

  vaultAgentConfig = pkgs.writeText "vault-agent.hcl" ''
    exit_after_auth = false
    pid_file = "/run/vault-agent.pid"

    auto_auth {
      method "approle" {
        config = {
          role_id_file_path   = "${persistentSecretDir}/vault-role-id"
          secret_id_file_path = "${persistentSecretDir}/vault-secret-id"
          remove_secret_id_file_after_reading = false
        }
      }
      sink "file" {
        config = {
          path = "${secretDir}/vault-token"
          mode = 0640
        }
      }
    }

    vault {
      address = "${vaultAddr}"
    }

    template { 
      source = "${haproxyTmpl}" 
      destination = "${certDir}/haproxy.pem" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl reload-or-restart --no-block haproxy.service || true'" 
    }
    template { 
      source = "${coturnCertTmpl}" 
      destination = "${certDir}/coturn-fullchain.pem" 
      perms = 0644 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block coturn.service || true'" 
    }
    template { 
      source = "${coturnKeyTmpl}" 
      destination = "${certDir}/coturn.key" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block coturn.service || true'" 
    }

    template { 
      source = "${synapseSecretsTmpl}" 
      destination = "${secretDir}/synapse-secrets.yaml" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block matrix-synapse.service || true'" 
    }
    template { 
      source = "${synapseEmailTmpl}" 
      destination = "${secretDir}/synapse-email.yaml" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block matrix-synapse.service || true'" 
    }
    template { 
      source = "${masConfigTmpl}" 
      destination = "${secretDir}/mas-config.yaml" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block matrix-authentication-service.service || true'" 
    }
    template { 
      source = "${coturnSecretTmpl}" 
      destination = "${secretDir}/coturn-secret" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block coturn.service || true'" 
    }
    template { 
      source = "${coturnSecretEnvTmpl}" 
      destination = "${secretDir}/coturn-secret-env" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block livekit.service || true'" 
    }
  '';
in
{
  users.groups.matrix-secrets = { };

  systemd = {
    tmpfiles.rules = [
      "d ${certDir} 0755 root root -"
      "d ${secretDir} 0750 root matrix-secrets -"
      "d ${persistentSecretDir} 0700 root root -"
    ];

    services = {
      # Vault Agent Bootstrap:
      # Ensures that all runtime secrets are rendered before any dependent
      # services are allowed to start.
      vault-agent-init = {
        description = "Vault Agent: Initial Secret Rendering";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        path = [
          pkgs.glibc.bin
          pkgs.systemd
          pkgs.bash
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.vault}/bin/vault agent -config=${vaultAgentConfig} -exit-after-auth";
          Environment = [ "HOME=/tmp" ];
          ReadWritePaths = [
            secretDir
            certDir
            "/run"
          ];
          ReadOnlyPaths = [ persistentSecretDir ];
        };
      };

      # Vault Agent Refresh:
      # Background daemon that maintains active Vault authentication and
      # re-renders secrets whenever the upstream KV versions increment.
      vault-agent = {
        description = "Vault Agent: Background Secret Refresh";
        after = [ "vault-agent-init.service" ];
        requires = [ "vault-agent-init.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [
          pkgs.glibc.bin
          pkgs.systemd
          pkgs.bash
        ];
        serviceConfig = {
          ExecStart = "${pkgs.vault}/bin/vault agent -config=${vaultAgentConfig}";
          Restart = "on-failure";
          RestartSec = "10s";
          Environment = [ "HOME=/tmp" ];
          ReadWritePaths = [
            secretDir
            certDir
            "/run"
          ];
          ReadOnlyPaths = [ persistentSecretDir ];
        };
      };

      # Service Dependencies:
      # All services that consume runtime secrets are sequenced after the
      # vault-agent-init one-shot to prevent race conditions during boot.
      coturn = {
        after = [ "vault-agent-init.service" ];
        serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
      };
      haproxy = {
        after = [ "vault-agent-init.service" ];
        serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
      };
      matrix-synapse = {
        after = [ "vault-agent-init.service" ];
        serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
      };
      matrix-authentication-service = {
        after = [ "vault-agent-init.service" ];
        serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
      };
      livekit = {
        after = [ "vault-agent-init.service" ];
        serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
      };
    };
  };
}
