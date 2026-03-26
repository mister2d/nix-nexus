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

      # QR Code Login (MSC4108):
      # Enables the rendezvous endpoint on Synapse required for "login via QR code"
      # in Element X / Element Web. Requires MAS (matrix_authentication_service) to
      # be enabled — validated at Synapse startup. msc4108_delegation_endpoint is
      # mutually exclusive with msc4108_enabled and is not set here.
      experimental_features = {
        # MSC4108: QR code login — requires MAS to be enabled.
        msc4108_enabled = true;
        # MSC4143: MatrixRTC transport discovery endpoint.
        # Registers /_matrix/client/unstable/org.matrix.msc4143/rtc/transports,
        # which clients (Element X, Element Call) query to discover LiveKit focus.
        # Returns the contents of matrix_rtc.transports below.
        msc4143_enabled = true;
      };

      # MatrixRTC transport configuration (MSC4143).
      # Served at /_matrix/client/unstable/org.matrix.msc4143/rtc/transports.
      # Must match the livekit_service_url in the well-known rtc_foci entry.
      matrix_rtc.transports = [
        {
          type = "livekit";
          livekit_service_url = "https://${matrixDomain}/livekit/jwt";
        }
      ];
    };
  };
}
