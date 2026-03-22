{
  lib,
  pkgs,
  ...
}:
let
  certDir = "/run/certs";
  kvPath = "kv-v2/letsencrypt/certificates/live/novuscotia.com";

  # Certificate Template Definitions:
  # Templates fetch fullchain and private keys from the fleet Vault instance (KV-v2 secrets engine).
  # HAProxy requires a combined PEM file, while Coturn requires separate cert/key files.
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

  # Consul Template Configuration:
  # Orchestrates the rendering and rotation of certificates.
  # Automatically reloads dependent services upon certificate renewal.
  ctConfig = pkgs.writeText "consul-template-certs.hcl" ''
    vault {
      unwrap_token = false
      renew_token  = true
    }

    template {
      source      = "${haproxyTmpl}"
      destination = "${certDir}/haproxy.pem"
      perms       = "0640"
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

  # Certificate Lifecycle Service:
  # Manages the automated provisioning of TLS certificates from the centralized Vault PKI/KV.
  systemd.services.consul-template-certs = {
    description = "consul-template: render TLS certs from Vault KV for avina services";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    before = [
      "coturn.service"
      "haproxy.service"
    ];
    serviceConfig = {
      # Integration with fleet-wide Vault infrastructure.
      Environment = [ "VAULT_ADDR=https://vault.service.consul:8200" ];
      EnvironmentFile = "/run/secrets/vault-token.env";
      ExecStart = lib.escapeShellArgs [
        "${pkgs.consul-template}/bin/consul-template"
        "-config"
        ctConfig
      ];
      Restart = "on-failure";
      RestartSec = "30s";
      NoNewPrivileges = true;
      PrivateTmp = false; # Permissions needed to write to shared /run/certs
      ProtectSystem = "strict";
      ReadWritePaths = [ certDir ];
    };
  };
}
