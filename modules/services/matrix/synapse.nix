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
        # MSC3266: Room Summary API. Required by Element Call for knocking over
        # federation (standalone mode join-via-knock flow).
        msc3266_enabled = true;
        # MSC4222: sync v2 state_after. Required by Element Call to correctly
        # track room membership and participant state during a call.
        msc4222_enabled = true;
      };

      # MSC4140: Delayed Events — participation heartbeats for MatrixRTC.
      # Without this, call participants appear stuck in rooms after leaving.
      # Element Call self-hosting documentation lists this as required.
      max_event_delay_duration = "24h";

      # Rate limits: accommodate E2EE key sharing (bursty on join) and the
      # MatrixRTC heartbeat (0.2 events/s steady-state). Values from the
      # Element Call self-hosting documentation.
      rc_message = {
        per_second = 0.5;
        burst_count = 30;
      };
      rc_delayed_event_mgmt = {
        per_second = 1;
        burst_count = 20;
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
