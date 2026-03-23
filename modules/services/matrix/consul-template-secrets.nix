{
  pkgs,
  vaultAddr,
  cloudflaredTunnelId,
  matrixDomain,
  ...
}:
let
  certDir = "/run/certs";
  secretDir = "/run/secrets";
  persistentSecretDir = "/var/lib/secrets";
  kvPath = "kv-v2/letsencrypt/certificates/live/novuscotia.com";
  matrixKvPath = "kv-v2/infrastructure/matrix/avina";
  smtpKvPath = "kv-v2/infrastructure/smtp";

  cloudflaredService = "cloudflared-tunnel-${cloudflaredTunnelId}.service";

  # ── Runtime Templates ───────────────────────────────────────────────────

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

  synapseSecretsTmpl = pkgs.writeText "synapse-secrets.ctmpl" ''
    {{ with secret "${matrixKvPath}/synapse" }}
    macaroon_secret_key: "{{ .Data.data.macaroon_secret_key }}"
    form_secret: "{{ .Data.data.form_secret }}"
    registration_shared_secret: "{{ .Data.data.registration_shared_secret }}"
    turn_shared_secret: "{{ .Data.data.turn_shared_secret }}"
    matrix_authentication_service:
      secret: "{{ .Data.data.mas_shared_secret }}"
    {{ end }}
  '';

  synapseEmailTmpl = pkgs.writeText "synapse-email.ctmpl" ''
    {{ with secret "${smtpKvPath}" }}
    email:
      smtp_pass: "{{ .Data.data.smtp_password }}"
    {{ end }}
  '';

  masConfigTmpl = pkgs.writeText "mas-config.ctmpl" ''
    {{ with secret "${matrixKvPath}/mas" }}
    http:
      public_base: "https://${matrixDomain}"
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
      encryption: "{{ .Data.data.encryption_key }}"
    upstream_oauth2:
      providers:
        - id: keycloak
          issuer: "{{ .Data.data.oidc_issuer }}"
          client_id: "{{ .Data.data.oidc_client_id }}"
          client_secret: "{{ .Data.data.oidc_client_secret }}"
    matrix:
      kind: synapse
      homeserver: "${matrixDomain}"
      secret: "{{ .Data.data.mas_shared_secret }}"
      endpoint: "http://127.0.0.1:8008"
    {{ end }}
  '';

  cloudflaredTmpl = pkgs.writeText "cloudflared.ctmpl" ''
    {{ with secret "${matrixKvPath}/cloudflared" }}
    {
      "AccountTag": "{{ .Data.data.account_id }}",
      "TunnelID": "{{ .Data.data.tunnel_id }}",
      "TunnelName": "avina-tunnel",
      "TunnelSecret": "{{ .Data.data.tunnel_secret }}"
    }
    {{ end }}
  '';

  cloudflaredCertTmpl = pkgs.writeText "cloudflared-cert.ctmpl" ''
    {{ with secret "kv-v2/cloudflare/vpc-origin-cert" }}
    {{- .Data.data.fullchain -}}
    {{ end }}
  '';

  coturnSecretTmpl = pkgs.writeText "coturn-secret.ctmpl" ''
    {{ with secret "${matrixKvPath}/synapse" }}{{ .Data.data.turn_shared_secret }}{{ end }}
  '';

  coturnSecretEnvTmpl = pkgs.writeText "coturn-env.ctmpl" ''
    {{ with secret "${matrixKvPath}/synapse" }}
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

    # Certificate Management
    template { 
      source = "${haproxyTmpl}" 
      destination = "${certDir}/haproxy.pem" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl reload haproxy.service || true'" 
    }
    template { 
      source = "${coturnCertTmpl}" 
      destination = "${certDir}/coturn-fullchain.pem" 
      perms = 0644 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl reload coturn.service || true'" 
    }
    template { 
      source = "${coturnKeyTmpl}" 
      destination = "${certDir}/coturn.key" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl reload coturn.service || true'" 
    }

    # Secret Management
    template { 
      source = "${synapseSecretsTmpl}" 
      destination = "${secretDir}/synapse-secrets.yaml" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart matrix-synapse.service || true'" 
    }
    template { 
      source = "${synapseEmailTmpl}" 
      destination = "${secretDir}/synapse-email.yaml" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart matrix-synapse.service || true'" 
    }
    template { 
      source = "${masConfigTmpl}" 
      destination = "${secretDir}/mas-config.yaml" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart matrix-authentication-service.service || true'" 
    }
    template { 
      source = "${cloudflaredTmpl}" 
      destination = "${secretDir}/cloudflared-creds.json" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart ${cloudflaredService} || true'" 
    }
    template { 
      source = "${cloudflaredCertTmpl}" 
      destination = "${secretDir}/cloudflared-cert.pem" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart ${cloudflaredService} || true'" 
    }
    template { 
      source = "${coturnSecretTmpl}" 
      destination = "${secretDir}/coturn-secret" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart coturn.service || true'" 
    }
    template { 
      source = "${coturnSecretEnvTmpl}" 
      destination = "${secretDir}/coturn-secret-env" 
      perms = 0640 
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart livekit.service || true'" 
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
      # Initial Rendering:
      # Ensures that all secrets and certificates exist before any application
      # attempts to start, eliminating race conditions.
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

      # Background Daemon:
      # Watches for secret changes in Vault and re-renders templates
      # to maintain system freshness.
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
      # Applications MUST wait for the initial secret rendering to complete.
      coturn.after = [ "vault-agent-init.service" ];
      haproxy.after = [ "vault-agent-init.service" ];
      matrix-synapse.after = [ "vault-agent-init.service" ];
      matrix-authentication-service.after = [ "vault-agent-init.service" ];
      livekit.after = [ "vault-agent-init.service" ];
      "${cloudflaredService}".after = [ "vault-agent-init.service" ];

      coturn.serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
      haproxy.serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
      matrix-synapse.serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
      matrix-authentication-service.serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
      livekit.serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
      "${cloudflaredService}".serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
    };
  };
}
