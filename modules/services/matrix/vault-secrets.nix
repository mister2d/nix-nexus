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
  whatsappPath = "${matrixKvBase}/whatsapp";

  # Router external WAN IP — used by coturn to advertise the correct relay address
  # and by LiveKit TURN TLS cert (same cert domain). Read-only; policy fragment in
  # vault/policies/avina-matrix-router-read.hcl must be attached to the AppRole.
  routerPath = "kv-v2/data/infrastructure/router";

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

  # WAN IP for coturn external-ip and LiveKit TURN domain resolution.
  coturnExternalIpTmpl = pkgs.writeText "coturn-external-ip.ctmpl" ''
    {{ with secret "${routerPath}" }}{{ .Data.data.external_ip }}{{ end }}
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
      endpoint: "http://127.0.0.1:8182"
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
      smtp_user: "{{ $smtp.Data.data.smtp_login }}"
      smtp_pass: "{{ $smtp.Data.data.smtp_password }}"
      require_transport_security: true
      notif_from: "Matrix <noreply@{{ $c.Data.data.matrix_domain }}>"
    {{ end }}
    {{ end }}
  '';

  # MAS Configuration:
  # All secrets pulled from two KV paths: config (domains/names) and mas (keys/secrets).
  # SMTP credentials are pulled from the shared smtp path for the email transport.
  #
  # claims_imports templates use Tera syntax ({{ }}) which conflicts with Consul template
  # delimiters; literal braces are emitted via {{ "{{" }} and {{ "}}" }} escapes.
  masConfigTmpl = pkgs.writeText "mas-config.ctmpl" ''
    {{ with $c := secret "${configPath}" }}
    {{ with $m := secret "${masPath}" }}
    {{ with $smtp := secret "${smtpPath}" }}
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
          proxy_protocol: true
        - name: internal
          resources:
            - name: discovery
            - name: oauth
          binds: [{ host: "127.0.0.1", port: 8182 }]
    database:
      host: "/run/postgresql"
      database: "matrix-authentication-service"
      username: "matrix-authentication-service"
    secrets:
      encryption: "{{ $m.Data.data.encryption_key }}"
      keys:
        - kid: "mas-rsa-01"
          key_file: ${secretDir}/mas-signing-rsa.key
        - kid: "mas-ec-01"
          key_file: ${secretDir}/mas-signing-ec.key
    passwords:
      enabled: false
    email:
      from: '"Matrix" <noreply@{{ $c.Data.data.matrix_domain }}>'
      transport: smtp
      hostname: smtp.mailgun.org
      port: 587
      mode: starttls
      username: "{{ $smtp.Data.data.smtp_login }}"
      password: "{{ $smtp.Data.data.smtp_password }}"
    branding:
      service_name: "{{ $c.Data.data.instance_name }}"
      tos_uri: "https://{{ $c.Data.data.matrix_domain }}/tos"
    rate_limiting:
      account_recovery:
        per_ip:
          burst: 3
          per_second: 0.0008
        per_address:
          burst: 3
          per_second: 0.0002
      login:
        per_ip:
          burst: 3
          per_second: 0.05
        per_account:
          burst: 1800
          per_second: 0.5
      registration:
        burst: 3
        per_second: 0.0008
    upstream_oauth2:
      providers:
        - id: "01H75Z9682SZK6WEZKD98Z2YBP"
          human_name: "SSO"
          issuer: "{{ $m.Data.data.oidc_issuer }}"
          client_id: "{{ $m.Data.data.oidc_client_id }}"
          client_secret: "{{ $m.Data.data.oidc_client_secret }}"
          token_endpoint_auth_method: "client_secret_basic"
          scope: "openid profile email"
          fetch_userinfo: true
          claims_imports:
            localpart:
              action: force
              template: "{{ "{{" }} user.preferred_username {{ "}}" }}"
            displayname:
              action: suggest
              template: "{{ "{{" }} user.name {{ "}}" }}"
            email:
              action: force
              template: "{{ "{{" }} user.email {{ "}}" }}"
              set_email_verification: import
          on_backchannel_logout: logout_browser_only
    matrix:
      kind: synapse
      homeserver: "{{ $c.Data.data.matrix_domain }}"
      secret: "{{ $m.Data.data.mas_shared_secret }}"
      endpoint: "http://127.0.0.1:8008"
    policy:
      data:
        client_registration:
          # Element Call is a public SPA client (oidc-client-ts) that performs
          # dynamic client registration without a client_uri field. MAS's built-in
          # OPA policy rejects registrations missing client_uri by default.
          # Setting this to true allows Element Call to register dynamically so
          # the native OIDC (MSC3861) flow can complete; without it, Element Call
          # falls back to the Matrix compat login endpoint which rejects all logins
          # because passwords are disabled.
          allow_missing_client_uri: true
    {{ end }}
    {{ end }}
    {{ end }}
  '';

  coturnSecretTmpl = pkgs.writeText "coturn-secret.ctmpl" ''
    {{ with secret "${synapsePath}" }}{{ .Data.data.turn_shared_secret }}{{ end }}
  '';

  # WhatsApp Bridge Secrets:
  # encryption_pickle_key: generated once, never rotated — invalidates all bridge sessions.
  #
  # Double-puppeting note: login_shared_secret is NOT used here. MAS (MSC3861) removes
  # m.login.application_service, making the shared-secret approach incompatible.
  # To enable double-puppeting after the bridge is running:
  #   1. Read as_token from /var/lib/mautrix-whatsapp/whatsapp-registration.yaml
  #   2. Store in Vault as: as_token:THE_TOKEN
  #   3. Set MAUTRIX_WHATSAPP_BRIDGE_LOGIN_SHARED_SECRET=as_token:THE_TOKEN here
  #      (the NixOS module injects this into double_puppet.secrets."<domain>")
  whatsappEnvTmpl = pkgs.writeText "whatsapp-env.ctmpl" ''
    {{ with secret "${whatsappPath}" }}
    MAUTRIX_WHATSAPP_ENCRYPTION_PICKLE_KEY={{ .Data.data.encryption_pickle_key }}
    MAUTRIX_WHATSAPP_BRIDGE_LOGIN_SHARED_SECRET=as_token:{{ .Data.data.as_token }}
    {{ end }}
  '';

  coturnSecretEnvTmpl = pkgs.writeText "coturn-env.ctmpl" ''
    {{ with secret "${synapsePath}" }}
    LIVEKIT_TURN_SHARED_SECRET={{ .Data.data.turn_shared_secret }}
    {{ end }}
  '';

  # MAS Signing Keys:
  # Two keys rendered as separate files to avoid multi-line PEM indentation
  # issues in YAML. MAS references them via key_file.
  #
  # Security posture: ECDSA P-384 (primary, hardened) + RSA-2048 (mandatory
  # for OIDC Core spec RS256 compliance). Modern clients preferentially use
  # ES384; RSA-2048 exists solely for spec compliance.
  #
  # Both must be generated once and never rotated — changing a signing key
  # invalidates all active sessions and issued tokens.
  masSigningKeyEcTmpl = pkgs.writeText "mas-signing-key-ec.ctmpl" ''
    {{ with secret "${masPath}" }}{{ .Data.data.signing_key_ec_pem }}{{ end }}
  '';

  masSigningKeyRsaTmpl = pkgs.writeText "mas-signing-key-rsa.ctmpl" ''
    {{ with secret "${masPath}" }}{{ .Data.data.signing_key_rsa_pem }}{{ end }}
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
      # livekit TURN also uses this cert — restart both on renewal
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block coturn.service livekit.service || true'"
    }
    template {
      source = "${coturnKeyTmpl}"
      destination = "${certDir}/coturn.key"
      perms = 0640
      group = "matrix-secrets"
      # livekit TURN also uses this key — restart both on renewal
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block coturn.service livekit.service || true'"
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
      source = "${masSigningKeyEcTmpl}"
      destination = "${secretDir}/mas-signing-ec.key"
      perms = 0640
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block matrix-authentication-service.service || true'"
    }
    template {
      source = "${masSigningKeyRsaTmpl}"
      destination = "${secretDir}/mas-signing-rsa.key"
      perms = 0640
      group = "matrix-secrets"
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block matrix-authentication-service.service || true'"
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
    template {
      source      = "${coturnExternalIpTmpl}"
      destination = "${secretDir}/coturn-external-ip"
      perms       = 0640
      group       = "matrix-secrets"
      command     = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block coturn.service || true'"
    }
    template {
      source      = "${whatsappEnvTmpl}"
      destination = "${secretDir}/whatsapp-env"
      perms       = 0640
      group       = "matrix-secrets"
      command     = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block mautrix-whatsapp.service || true'"
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
      mautrix-whatsapp = {
        after = [
          "vault-agent-init.service"
          "postgresql-mautrix-whatsapp-perms.service"
        ];
        serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
      };
    };
  };
}
