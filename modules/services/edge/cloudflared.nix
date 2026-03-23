{
  lib,
  pkgs,
  ...
}:
let
  tunnelId = "74839201-abcd-efgh-ijkl-1234567890ab";
  matrixDomain = "novuscotia.com";
  callDomain = "call.novuscotia.com";
  # Path managed by vault-agent
  credentialsFile = "/run/secrets/cloudflared-creds.json";
  originCertFile = "/run/secrets/cloudflared-cert.pem";
in
{
  # Cloudflare Edge Connectivity:
  # Establishes a secure, encrypted tunnel to the Cloudflare network,
  # routing external traffic to the local HAProxy ingress.
  services.cloudflared = {
    enable = true;
    tunnels.${tunnelId} = {
      inherit credentialsFile;
      default = "http_status:404";
      ingress = {
        # Matrix Client/Federation/MAS Ingress:
        # Routes traffic to HAProxy on the secure loopback port.
        "${matrixDomain}" = {
          service = "https://127.0.0.1:8443";
          originRequest = {
            # Bypasses hostname validation for the internal loopback link.
            noTLSVerify = true;
          };
        };
        # Element Call Ingress:
        "${callDomain}" = {
          service = "https://127.0.0.1:8443";
          originRequest = {
            noTLSVerify = true;
          };
        };
      };
    };
  };

  # Tunnel Hardening & Identity:
  # Injects the Cloudflare origin certificate and bypasses systemd credential
  # loading to ensure reliable tunnel establishment.
  systemd.services."cloudflared-tunnel-${tunnelId}" = {
    serviceConfig = {
      # Bypassing LoadCredential to resolve systemd execution failures ('Protocol error').
      # The credentials file is accessed directly from its source path.
      ExecStart = lib.mkForce "${pkgs.cloudflared}/bin/cloudflared tunnel --credentials-file ${credentialsFile} run ${tunnelId}";

      # Origin Identity:
      # Propagates the VPC-specific origin certificate for tunnel authentication.
      Environment = [ "TUNNEL_ORIGIN_CERT=${originCertFile}" ];

      # Security:
      # Restricts the service to minimal required capabilities.
      CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
      NoNewPrivileges = true;
    };
  };

  # Transition Strategy:
  # Note: Avina will join the self-hosted Headscale VPN mesh in a future phase.
  # Until then, administration is handled via Cloudflare SSH and direct console.
}
