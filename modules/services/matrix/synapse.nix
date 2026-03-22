{
  matrixDomain,
  coturnRealm,
  ...
}:
{
  services.matrix-synapse = {
    enable = true;
    withJemalloc = true;

    settings = {
      server_name = matrixDomain;
      public_baseurl = "https://${matrixDomain}";

      # Native OIDC delegation to MAS (Stable since 1.103.0)
      matrix_authentication_service = {
        enabled = true;
        issuer = "https://auth.${matrixDomain}"; # matches MAS_DOMAIN
        client_id = "synapse"; # Matches 'matrix.secret' in MAS config
        # client_secret is in /run/secrets/synapse-secrets.yaml
      };

      # MatrixRTC features (advising clients of support)
      experimental_features = {
        # MSC3401 and MSC3843 are stable/integrated in 1.149.1
      };

      # Disable password auth (handled by MAS)
      password_config.enabled = false;

      # TURN configuration
      turn_uris = [
        "turn:${coturnRealm}:3478?transport=udp"
        "turn:${coturnRealm}:3478?transport=tcp"
        "turns:${coturnRealm}:5349?transport=tcp"
      ];
      # turn_shared_secret is in /run/secrets/synapse-secrets.yaml
      turn_user_lifetime = "86400000ms";

      # Federation
      federation_domain_whitelist = [ matrixDomain ];

      # Proxy Trust
      trusted_proxies = [ "127.0.0.1" ];

      # Database
      database = {
        name = "psycopg2";
        args = {
          user = "matrix-synapse";
          database = "matrix-synapse";
          host = "/run/postgresql";
          cp_min = 5;
          cp_max = 10;
          # ── Resilience ──────────────────────────────────────────────────────
          # Prevent silent connection drops
          keepalives_idle = 10;
          keepalives_interval = 10;
          keepalives_count = 3;
        };
      };

      # Listeners (proxied by HAProxy)
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
    };

    extraConfigFiles = [ "/run/secrets/synapse-secrets.yaml" ];
  };

  # Service ordering
  systemd.services.matrix-synapse = {
    after = [
      "postgresql.service"
      "matrix-authentication-service.service"
    ];
    requires = [
      "postgresql.service"
      "matrix-authentication-service.service"
    ];
  };
}
