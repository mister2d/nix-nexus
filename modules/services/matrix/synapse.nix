{
  matrixDomain,
  coturnRealm,
  federatedDomains ? [ ],
  ...
}:
{
  services.matrix-synapse = {
    enable = true;
    withJemalloc = true;

    # ── Zero-Secrets-in-Store ──────────────────────────────────────────────
    # Only structural/non-secret config is here. All identities (domains,
    # keys, OIDC client secrets) are rendered from Vault to /run/secrets.
    extraConfigFiles = [
      "/run/secrets/synapse-secrets.yaml"
      "/run/secrets/synapse-email.yaml"
    ];

    settings = {
      # server_name, public_baseurl, and instance_name are PULLED FROM VAULT.

      # Federation (Structural)
      federation_domain_whitelist = [ matrixDomain ] ++ federatedDomains;
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
          keepalives_idle = 10;
          keepalives_interval = 10;
          keepalives_count = 3;
        };
      };

      # Resource Management (ZFS-optimized)
      caches = {
        global_factor = 0.5;
      };

      # NAT Traversal (TURN)
      turn_uris = [
        "turn:${coturnRealm}:3478?transport=udp"
        "turn:${coturnRealm}:3478?transport=tcp"
        "turns:${coturnRealm}:5349?transport=tcp"
      ];
      turn_user_lifetime = 86400000;

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

      # Authentication and Registration
      password_config.enabled = false;
      enable_registration = false;
      allow_guest_access = false;
    };
  };
}
