{
  matrixDomain,
  rtcDomain,
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

      # TURN Relay:
      # Integrated with LiveKit's built-in TURN server. Clients receive these
      # URIs from Synapse and use them as a fallback when direct WebRTC UDP
      # is blocked. turn_shared_secret is PULLED FROM VAULT.
      turn_uris = [
        "stun:${rtcDomain}:3478"
        "turn:${rtcDomain}:3478?transport=udp"
        "turn:${rtcDomain}:3478?transport=tcp"
        "turns:${rtcDomain}:5349?transport=tcp"
      ];
      # HMAC-SHA1 shared secret for generating time-limited credentials.
      # turn_shared_secret: (rendered from Vault to /run/secrets/synapse-secrets.yaml)
      turn_user_lifetime = 86400000; # 1 day

      # Federation (Structural)
      federation_domain_whitelist = [ matrixDomain ] ++ federatedDomains;
      suppress_key_server_warning = true;
      # Enforce minimum TLS 1.2 on outbound federation connections.
      federation_client_minimum_tls_version = "1.2";

      # SSRF Prevention:
      # Explicitly blacklist RFC-1918, loopback, link-local, and reserved ranges
      # so Synapse cannot be used to probe internal services via URL fetch endpoints
      # (media proxy, URL previews, etc.). Synapse has built-in defaults but listing
      # them explicitly makes the security posture verifiable.
      ip_range_blacklist = [
        "127.0.0.0/8"
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "100.64.0.0/10"
        "192.0.0.0/24"
        "169.254.0.0/16"
        "192.88.99.0/24"
        "198.18.0.0/15"
        "198.51.100.0/24"
        "203.0.113.0/24"
        "224.0.0.0/4"
        "::1/128"
        "fe80::/10"
        "fc00::/7"
        "2001:db8::/32"
        "ff00::/8"
        "fec0::/10"
      ];

      # Privacy hardening: prevent unauthenticated enumeration of display names
      # and avatar URLs. Without this any unauthenticated client can scrape profiles.
      require_auth_for_profile_requests = true;

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
        # Registers /_matrix/client/unstable/org.matrix.msc4143/rtc/transports.
        # In practice, haproxy.nix intercepts all requests to this path with a
        # static http-request return rule (is_rtc_discovery ACL) before they
        # reach Synapse — bypassing Synapse's auth requirement on this endpoint.
        # The matrix_rtc.transports block below is therefore not actively served
        # but mirrors the HAProxy static response for consistency and as a fallback
        # if the HAProxy intercept is ever removed.
        msc4143_enabled = true;
        # MSC3266: Room Summary API. Required by Element Call for knocking over
        # federation (standalone mode join-via-knock flow).
        msc3266_enabled = true;
        # MSC4222: sync v2 state_after. Required by Element Call to correctly
        # track room membership and participant state during a call.
        msc4222_enabled = true;
        # MSC4028: push encrypted event content. Allows push notifications to
        # include event content for encrypted rooms without decrypting server-side.
        # Improves notification privacy — no content leaks to push gateway.
        msc4028_push_encrypted_events = true;
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
          livekit_service_url = "https://${rtcDomain}/livekit/jwt";
          livekit_alias = matrixDomain;
        }
        {
          type = "rtc_transports";
          livekit_service_url = "https://${rtcDomain}/livekit/jwt";
          livekit_alias = matrixDomain;
        }
        {
          type = "foci";
          livekit_service_url = "https://${rtcDomain}/livekit/jwt";
          livekit_alias = matrixDomain;
        }
      ];
    };
  };
}
