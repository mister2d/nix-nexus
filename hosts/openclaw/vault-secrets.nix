{
  pkgs,
  ...
}:
let
  secretDir = "/run/secrets";
  persistentSecretDir = "/var/lib/secrets";
  vaultAddr = "https://vault.service.consul:8200";

  openclawPath = "kv-v2/data/infrastructure/tailscale";

  # Vault Agent rendering template for Tailscale auth key
  # Use printf "%s" to ensure no trailing newline, which causes "invalid key" errors.
  tailscaleKeyTmpl = pkgs.writeText "tailscale-key.ctmpl" ''
    {{ with secret "${openclawPath}" -}}
    {{ .Data.data.matrix_auth_key | printf "%s" -}}
    {{- end }}
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
      perms = 0600
      # Restart tailscaled when the key changes
      command = "${pkgs.bash}/bin/bash -c '${pkgs.systemd}/bin/systemctl restart --no-block tailscaled.service || true'"
    }
  '';
in
{
  systemd = {
    tmpfiles.rules = [
      "d ${secretDir} 0750 root root -"
      "d ${persistentSecretDir} 0700 root root -"
    ];

    services = {
      vault-agent-init = {
        description = "Vault Agent: Initial Tailscale Secret Rendering";
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
            "/run"
          ];
          ReadOnlyPaths = [ persistentSecretDir ];
        };
      };

      tailscaled = {
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
