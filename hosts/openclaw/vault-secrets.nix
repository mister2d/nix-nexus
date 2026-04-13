{
  pkgs,
  ...
}:
let
  certDir = "/run/certs";
  secretDir = "/run/secrets";
  persistentSecretDir = "/var/lib/secrets";
  vaultAddr = "https://vault.service.consul:8200";

  openclawPath = "kv-v2/data/infrastructure/tailscale";
  openclawMatrixPath = "kv-v2/data/infrastructure/openclaw/matrix";
  openclawConfigPath = "kv-v2/data/infrastructure/openclaw/config";
  matrixConfigPath = "kv-v2/data/infrastructure/matrix/avina/config";
  certDomain = "novuscotia.com";
  kvPath = "kv-v2/data/letsencrypt/certificates/live/${certDomain}";

  # Vault Agent rendering template for Tailscale auth key
  # Use printf "%s" to ensure no trailing newline, which causes "invalid key" errors.
  tailscaleKeyTmpl = pkgs.writeText "tailscale-key.ctmpl" ''
    {{ with secret "${openclawPath}" -}}
    {{ .Data.data.matrix_auth_key | printf "%s" -}}
    {{- end }}
  '';

  # OpenClaw Environment File:
  # Renders Vault secrets as env vars loaded by the openclaw-gateway systemd user unit.
  # openclaw.json references these via { "source": "env", "provider": "default", "id": "VAR" }.
  openclawEnvTmpl = pkgs.writeText "openclaw.env.ctmpl" ''
    {{ with $mc := secret "${matrixConfigPath}" -}}
    {{ with $om := secret "${openclawMatrixPath}" -}}
    {{ with $oc := secret "${openclawConfigPath}" -}}
    OPENCLAW_GATEWAY_TOKEN={{ $oc.Data.data.gateway_token }}
    OPENCLAW_MATRIX_ACCESS_TOKEN={{ $om.Data.data.access_token }}
    OPENCLAW_MATRIX_HOMESERVER=https://{{ $mc.Data.data.matrix_domain }}
    OPENCLAW_MATRIX_AUTO_JOIN_ROOM={{ $om.Data.data.initial_auto_join }}:{{ $mc.Data.data.matrix_domain }}
    OPENCLAW_GOPLACES_API_KEY={{ $oc.Data.data.go_places_api_key }}
    {{- end }}
    {{- end }}
    {{- end }}
  '';

  # HAProxy Wildcard Certificate:
  # Renders fullchain + privkey concatenated for HAProxy.
  haproxyTmpl = pkgs.writeText "haproxy-cert.ctmpl" ''
    {{ with secret "${kvPath}" }}
    {{ .Data.data.fullchain }}{{ .Data.data.privkey }}
    {{ end }}
  '';

  vaultAgentConfig = pkgs.writeText "vault-agent-openclaw.hcl" ''
    exit_after_auth = false
    pid_file = "/run/vault-agent-openclaw.pid"

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
      source = "${tailscaleKeyTmpl}"
      destination = "${secretDir}/tailscale.key"
      perms = 0640
      group = "openclaw-secrets"
      # Restart tailscaled when the key changes
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block tailscaled.service || true'"
    }

    template {
      source = "${haproxyTmpl}"
      destination = "${certDir}/haproxy.pem"
      perms = 0640
      group = "openclaw-secrets"
      # Reload HAProxy when the cert changes
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl reload-or-restart --no-block haproxy.service || true'"
    }

    template {
      source = "${openclawEnvTmpl}"
      destination = "${secretDir}/openclaw.env"
      user = "groot"
      perms = 0400
      # Restart the openclaw user service when secrets rotate
      command = "${pkgs.bash}/bin/bash -c 'su groot -s /bin/sh -c \"XDG_RUNTIME_DIR=/run/user/$(id -u groot) ${pkgs.systemd}/bin/systemctl --user restart --no-block openclaw-gateway.service\" || true'"
    }
  '';
in
{
  users.groups.openclaw-secrets = { };

  systemd = {
    tmpfiles.rules = [
      "d ${certDir} 0755 root openclaw-secrets -"
      "d ${secretDir} 0750 root openclaw-secrets -"
      "d ${persistentSecretDir} 0700 root root -"
    ];

    services = {
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

      tailscaled = {
        after = [ "vault-agent-init.service" ];
        wants = [ "vault-agent-init.service" ];
      };

      haproxy = {
        after = [ "vault-agent-init.service" ];
        wants = [ "vault-agent-init.service" ];
      };

      # Fix the race: ensure autoconnect services wait for the Vault rendering.
      tailscaled-autoconnect = {
        after = [ "vault-agent-init.service" ];
        wants = [ "vault-agent-init.service" ];
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      tailscale-autoconnect = {
        after = [ "vault-agent-init.service" ];
        wants = [ "vault-agent-init.service" ];
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };
    };
  };
}
