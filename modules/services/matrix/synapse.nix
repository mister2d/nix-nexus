{ matrixDomain, ... }:
{
  services.matrix-synapse = {
    enable = true;
    withPostgresql = true;

    # ── Zero-Secrets-in-Store ──────────────────────────────────────────────
    # Only structural/non-secret config is here. All identities (domains,
    # keys, OIDC client secrets) are rendered from Vault to /run/secrets.
    extraConfigFiles = [
      "/run/secrets/synapse-secrets.yaml"
      "/run/secrets/synapse-email.yaml"
    ];

    settings = {
      # server_name and public_baseurl are PULLED FROM VAULT SECRETS YAML.
      # Defining them here would override the Vault values.

      # Federation (Structural)
      federation_domain_whitelist = [ matrixDomain ];
      suppress_key_server_warning = true;

      # Database (Structural)
      database = {
        name = "psycopg2";
        args = {
          user = "matrix-synapse";
          database = "matrix-synapse";
          host = "/run/postgresql";
          cp_min = 5;
          cp_max = 10;
        };
      };

      # Resource Management (ZFS-optimized)
      caches = {
        global_factor = 0.5;
      };

      # Listeners
      listeners = [
        {
          port = 8008;
          tls = false;
          type = "http";
          x_forwarded = true;
          resources = [
            {
              names = [
                "client"
                "federation"
              ];
              compress = false;
            }
          ];
        }
      ];

      # Registration & Identity
      enable_registration = false;
      allow_guest_access = false;
    };
  };
}
