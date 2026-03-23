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
        "${matrixDomain}" = "http://127.0.0.1:8080";
        "${elementDomain}" = "http://127.0.0.1:8080";
        "${masDomain}" = "http://127.0.0.1:8080";
        "${callDomain}" = "http://127.0.0.1:8080";
      };
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
