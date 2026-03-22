{
  lib,
  pkgs,
  ...
}:
let
  certDir = "/run/certs";
  kvPath = "kv-v2/letsencrypt/certificates/live/novuscotia.com";

  # HAProxy needs fullchain + privkey in a single PEM file.
  haproxyTmpl = pkgs.writeText "haproxy-cert.ctmpl" ''
    {{ with secret "${kvPath}" }}
    {{ .Data.data.fullchain }}{{ .Data.data.privkey }}
    {{ end }}
  '';

  # Coturn needs cert and key as separate files.
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

  ctConfig = pkgs.writeText "consul-template-certs.hcl" ''
    vault {
      # VAULT_ADDR is injected via Environment= in the systemd unit.
      # VAULT_TOKEN is injected via EnvironmentFile= from the secrets file.
      unwrap_token = false
      renew_token  = true
    }

    template {
      source      = "${haproxyTmpl}"
      destination = "${certDir}/haproxy.pem"
      perms       = "0640"
      # Reload HAProxy after cert renders; || true is safe if HAProxy not yet started
      command     = "${pkgs.systemd}/bin/systemctl reload haproxy.service || true"
    }

    template {
      source      = "${coturnCertTmpl}"
      destination = "${certDir}/coturn-fullchain.pem"
      perms       = "0644"
      command     = "${pkgs.systemd}/bin/systemctl reload coturn.service || true"
    }

    template {
      source      = "${coturnKeyTmpl}"
      destination = "${certDir}/coturn.key"
      perms       = "0640"
      command     = "${pkgs.systemd}/bin/systemctl reload coturn.service || true"
    }
  '';
in
{
  systemd.tmpfiles.rules = [ "d ${certDir} 0755 root root -" ];

  systemd.services.consul-template-certs = {
    description = "consul-template: render TLS certs from Vault KV for avina services";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    # Both cert consumers must start after this service has rendered certs
    before = [
      "coturn.service"
      "haproxy.service"
    ];
    serviceConfig = {
      # VAULT_ADDR: non-secret; set directly. Matches ambient env from modules/user/bash.nix.
      Environment = [ "VAULT_ADDR=https://vault.service.consul:8200" ];
      # VAULT_TOKEN: secret; injected from file. File contains: VAULT_TOKEN=<token>
      EnvironmentFile = "/run/secrets/vault-token.env";
      ExecStart = lib.escapeShellArgs [
        "${pkgs.consul-template}/bin/consul-template"
        "-config"
        ctConfig
      ];
      Restart = "on-failure";
      RestartSec = "30s";
      NoNewPrivileges = true;
      PrivateTmp = false; # must write to /run/certs
      ProtectSystem = "strict";
      ReadWritePaths = [ certDir ];
    };
  };
}
