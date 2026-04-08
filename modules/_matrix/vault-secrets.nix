{ config, pkgs, ... }:
let
  cfg = config.matrix;
  certDir = "/run/certs";
  secretDir = "/run/secrets";
  persistentSecretDir = "/var/lib/secrets";
  matrixKvBase = "kv-v2/data/infrastructure/matrix/avina";
  configPath = "${matrixKvBase}/config";
  synapsePath = "${matrixKvBase}/synapse";
  masPath = "${matrixKvBase}/mas";
  kvPath = "kv-v2/data/letsencrypt/certificates/live/${cfg.certDomain}";
  smtpPath = "kv-v2/data/infrastructure/smtp";

  haproxyTmpl = pkgs.writeText "haproxy-cert.ctmpl" ''
    {{ with secret "${kvPath}" }}{{ .Data.data.fullchain }}{{ .Data.data.privkey }}{{ end }}
  '';
  turnCertTmpl = pkgs.writeText "turn-cert.ctmpl" ''
    {{ with secret "${kvPath}" }}{{ .Data.data.fullchain }}{{ end }}
  '';
  turnKeyTmpl = pkgs.writeText "turn-key.ctmpl" ''
    {{ with secret "${kvPath}" }}{{ .Data.data.privkey }}{{ end }}
  '';
  synapseSecretsTmpl = pkgs.writeText "synapse-secrets.ctmpl" ''
    {{ with $c := secret "${configPath}" }}{{ with $s := secret "${synapsePath}" }}
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
    {{ end }}{{ end }}
  '';
  livekitKeyTmpl = pkgs.writeText "livekit-key.ctmpl" ''
    {{ with $s := secret "${synapsePath}" }}lk-jwt-service: {{ $s.Data.data.turn_shared_secret }}{{ end }}
  '';
  synapseEmailTmpl = pkgs.writeText "synapse-email.ctmpl" ''
    {{ with $smtp := secret "${smtpPath}" }}{{ with $c := secret "${configPath}" }}
    email:
      enable_notifs: true
      smtp_host: "smtp.mailgun.org"
      smtp_port: 587
      smtp_user: "{{ $smtp.Data.data.smtp_login }}"
      smtp_pass: "{{ $smtp.Data.data.smtp_password }}"
      require_transport_security: true
      notif_from: "Matrix <noreply@{{ $c.Data.data.matrix_domain }}>"
    {{ end }}{{ end }}
  '';
  masConfigTmpl = pkgs.writeText "mas-config.ctmpl" ''
    {{ with $c := secret "${configPath}" }}{{ with $m := secret "${masPath}" }}{{ with $smtp := secret "${smtpPath}" }}
    http:
      public_base: "https://{{ $c.Data.data.auth_domain }}"
      listeners:
        - name: web
          resources: [{ name: discovery }, { name: human }, { name: oauth }, { name: compat }, { name: graphql }, { name: assets }]
          binds: [{ host: "127.0.0.1", port: 8181 }]
          proxy_protocol: true
        - name: internal
          resources: [{ name: discovery }, { name: oauth }]
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
            localpart: { action: force, template: "{{ "{{" }} user.preferred_username {{ "}}" }}" }
            displayname: { action: suggest, template: "{{ "{{" }} user.name {{ "}}" }}" }
            email: { action: force, template: "{{ "{{" }} user.email {{ "}}" }}", set_email_verification: import }
    matrix:
      kind: synapse
      homeserver: "{{ $c.Data.data.matrix_domain }}"
      secret: "{{ $m.Data.data.mas_shared_secret }}"
      endpoint: "http://127.0.0.1:8008"
    policy:
      data:
        client_registration:
          allow_missing_client_uri: true
    {{ end }}{{ end }}{{ end }}
  '';
  masSigningKeyEcTmpl = pkgs.writeText "mas-signing-key-ec.ctmpl" ''
    {{ with secret "${masPath}" }}{{ .Data.data.signing_key_ec_pem }}{{ end }}
  '';
  masSigningKeyRsaTmpl = pkgs.writeText "mas-signing-key-rsa.ctmpl" ''
    {{ with secret "${masPath}" }}{{ .Data.data.signing_key_rsa_pem }}{{ end }}
  '';

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
      sink "file" { config = { path = "${secretDir}/vault-token", mode = 0640 } }
    }
    vault { address = "${cfg.vaultAddr}" }
    template { source = "${haproxyTmpl}"; destination = "${certDir}/haproxy.pem"; perms = 0640; group = "matrix-secrets"; command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl reload-or-restart --no-block haproxy.service || true'" }
    template { source = "${turnCertTmpl}"; destination = "${certDir}/turn-fullchain.pem"; perms = 0644; group = "matrix-secrets"; command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block livekit.service || true'" }
    template { source = "${turnKeyTmpl}"; destination = "${certDir}/turn.key"; perms = 0640; group = "matrix-secrets"; command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block livekit.service || true'" }
    template { source = "${livekitKeyTmpl}"; destination = "${secretDir}/livekit.key"; perms = 0640; group = "matrix-secrets"; command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block livekit.service lk-jwt-service.service || true'" }
    template { source = "${synapseSecretsTmpl}"; destination = "${secretDir}/synapse-secrets.yaml"; perms = 0640; group = "matrix-secrets"; command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block matrix-synapse.service || true'" }
    template { source = "${synapseEmailTmpl}"; destination = "${secretDir}/synapse-email.yaml"; perms = 0640; group = "matrix-secrets"; command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block matrix-synapse.service || true'" }
    template { source = "${masSigningKeyEcTmpl}"; destination = "${secretDir}/mas-signing-ec.key"; perms = 0640; group = "matrix-secrets"; command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block matrix-authentication-service.service || true'" }
    template { source = "${masSigningKeyRsaTmpl}"; destination = "${secretDir}/mas-signing-rsa.key"; perms = 0640; group = "matrix-secrets"; command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block matrix-authentication-service.service || true'" }
    template { source = "${masConfigTmpl}"; destination = "${secretDir}/mas-config.yaml"; perms = 0640; group = "matrix-secrets"; command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block matrix-authentication-service.service || true'" }
  '';
in
{
  users.groups.matrix-secrets = { };
  systemd = {
    tmpfiles.rules = [ "d ${certDir} 0755 root root -" "d ${secretDir} 0750 root matrix-secrets -" "d ${persistentSecretDir} 0700 root root -" ];
    services = {
      vault-agent-init = {
        description = "Vault Agent: Initial Secret Rendering";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.glibc.bin pkgs.systemd pkgs.bash ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.vault}/bin/vault agent -config=${vaultAgentConfig} -exit-after-auth";
          Environment = [ "HOME=/tmp" ];
          ReadWritePaths = [ secretDir certDir "/run" ];
          ReadOnlyPaths = [ persistentSecretDir ];
        };
      };
      vault-agent = {
        description = "Vault Agent: Background Secret Refresh";
        after = [ "vault-agent-init.service" ];
        requires = [ "vault-agent-init.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.glibc.bin pkgs.systemd pkgs.bash ];
        serviceConfig = {
          ExecStart = "${pkgs.vault}/bin/vault agent -config=${vaultAgentConfig}";
          Restart = "on-failure";
          RestartSec = "10s";
          Environment = [ "HOME=/tmp" ];
          ReadWritePaths = [ secretDir certDir "/run" ];
          ReadOnlyPaths = [ persistentSecretDir ];
        };
      };
      haproxy.after = [ "vault-agent-init.service" ];
      haproxy.serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
      matrix-synapse.after = [ "vault-agent-init.service" ];
      matrix-synapse.serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
      matrix-authentication-service.after = [ "vault-agent-init.service" ];
      matrix-authentication-service.serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
      livekit.after = [ "vault-agent-init.service" ];
      livekit.serviceConfig.SupplementaryGroups = [ "matrix-secrets" ];
    };
  };
}
