{
  matrixDomain,
  elementDomain,
  masDomain,
  callDomain,
  cloudflaredTunnelId,
  ...
}:
{
  # Edge Ingress Tunnel:
  # Exposes internal stack components to the Cloudflare edge without opening
  # any inbound HTTP/S ports on the local firewall.
  services.cloudflared = {
    enable = true;
    tunnels."${cloudflaredTunnelId}" = {
      credentialsFile = "/run/secrets/cloudflared-creds.json";
      ingress = {
        "${matrixDomain}" = "https://127.0.0.1:8443";
        "${elementDomain}" = "https://127.0.0.1:8443";
        "${masDomain}" = "https://127.0.0.1:8443";
        "${callDomain}" = "https://127.0.0.1:8443";
      };
      originRequest.noTLSVerify = true;
      default = "http_status:404";
    };
  };

  # Inject origin certificate via environment variable as the NixOS module
  # does not expose an 'originCert' option for individual tunnels.
  systemd.services."cloudflared-tunnel-${cloudflaredTunnelId}".serviceConfig.Environment = [
    "TUNNEL_ORIGIN_CERT=/run/secrets/cloudflared-cert.pem"
  ];

  # VPN Transition Policy:
  # This host will join the fleet-wide Headscale mesh once the coordination
  # infrastructure is deployed, replacing the current edge-only connectivity model.
}
