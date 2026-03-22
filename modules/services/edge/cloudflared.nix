{
  matrixDomain,
  elementDomain,
  masDomain,
  callDomain,
  ...
}:
{
  # Edge Ingress Tunnel:
  # Exposes internal stack components to the Cloudflare edge without opening
  # any inbound HTTP/S ports on the local firewall.
  services.cloudflared = {
    enable = true;
    tunnels."74839201-abcd-efgh-ijkl-1234567890ab" = {
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

  # VPN Transition Policy:
  # This host will join the fleet-wide Headscale mesh once the coordination
  # infrastructure is deployed, replacing the current edge-only connectivity model.
}
