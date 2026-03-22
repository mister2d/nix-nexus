{
  matrixDomain,
  elementDomain,
  masDomain,
  ...
}:
{
  services.cloudflared = {
    enable = true;
    tunnels."74839201-abcd-efgh-ijkl-1234567890ab" = {
      # Example UUID
      credentialsFile = "/run/secrets/cloudflared-creds.json";
      ingress = {
        "${matrixDomain}" = "http://127.0.0.1:8080";
        "${elementDomain}" = "http://127.0.0.1:8080";
        "${masDomain}" = "http://127.0.0.1:8080";
      };
      default = "http_status:404";
    };
  };

  # Future: enrolled in self-hosted Headscale when that infrastructure is deployed.
  # Placeholder comment for Headscale transition as requested in AGENTS.md.
}
