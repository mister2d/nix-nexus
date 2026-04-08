{ config, lib, ... }:
let
  cfg = config.matrix;
in
{
  services.matrix-synapse = {
    enable = true;
    withJemalloc = true;

    # ── Zero-Secrets-in-Store ──────────────────────────────────────────────
    extraConfigFiles = [
      "/run/secrets/synapse-secrets.yaml"
      "/run/secrets/synapse-email.yaml"
    ];

    settings = {
      # server_name, public_baseurl, and instance_name are PULLED FROM VAULT.

      # TURN Relay:
      turn_uris = [
        "stun:${cfg.rtcDomain}:3478"
        "turn:${cfg.rtcDomain}:3478?transport=udp"
        "turn:${cfg.rtcDomain}:3478?transport=tcp"
        "turns:${cfg.rtcDomain}:5349?transport=tcp"
      ];
      turn_user_lifetime = 86400000; # 1 day

      # Federation (Structural)
      federation_domain_whitelist = lib.mkIf (cfg.federatedDomains != "*") (
        [ cfg.matrixDomain ] ++ cfg.federatedDomains
      );
      suppress_key_server_warning = true;
      federation_client_minimum_tls_version = "1.2";

      # SSRF Prevention:
      ip_range_blacklist = [
        "127.0.0.0/8" "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "100.64.0.0/10"
        "192.0.0.0/24" "169.254.0.0/16" "192.88.99.0/24" "198.18.0.0/15" "198.51.100.0/24"
        "203.0.113.0/24" "224.0.0.0/4" "::1/128" "fe80::/10" "fc00::/7" "2001:db8::/32"
        "ff00::/8" "fec0::/10"
      ];

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
        };
      };

      caches.global_factor = 0.5;

      # Listeners
      listeners = [
        {
          port = 8008;
          tls = false;
          type = "http";
          x_forwarded = true;
          resources = [
            { names = [ "client" "federation" ]; compress = false; }
          ];
        }
      ];

      password_config.enabled = false;
      enable_registration = false;
      allow_guest_access = false;

      experimental_features = {
        msc4108_enabled = true;
        msc4143_enabled = true;
        msc3266_enabled = true;
        msc4222_enabled = true;
        msc4028_push_encrypted_events = true;
      };

      max_event_delay_duration = "24h";

      rc_message = { per_second = 0.5; burst_count = 30; };
      rc_delayed_event_mgmt = { per_second = 1; burst_count = 20; };

      matrix_rtc.transports = [
        { type = "livekit"; livekit_service_url = "https://${cfg.rtcDomain}/livekit/jwt"; livekit_alias = cfg.matrixDomain; }
        { type = "rtc_transports"; livekit_service_url = "https://${cfg.rtcDomain}/livekit/jwt"; livekit_alias = cfg.matrixDomain; }
        { type = "foci"; livekit_service_url = "https://${cfg.rtcDomain}/livekit/jwt"; livekit_alias = cfg.matrixDomain; }
      ];
    };
  };
}
