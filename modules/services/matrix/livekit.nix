{
  lib,
  matrixDomain,
  rtcDomain,
  ...
}:
let
  # Key rendered by Vault Agent from turn_shared_secret.
  keyFile = "/run/secrets/livekit.key";
in
{
  services.livekit = {
    enable = true;
    inherit keyFile;
    settings = {
      port = 7880;
      bind_addresses = [ "0.0.0.0" ];

      room = {
        # Authentication Policy:
        # Prevent unauthenticated SFU room creation.
        auto_create = false;
        empty_timeout = 300;
        enabled_codecs = [
          { mime = "video/h264"; }
          { mime = "audio/opus"; }
        ];
      };

      rtc = {
        # UDP port range for WebRTC media. Must stay within the range
        # opened in hosts/avina/default.nix allowedUDPPortRanges (50100-50200).
        port_range_start = 50100;
        port_range_end = 50200;
        # TCP fallback for RTC media (not TURN — direct RTP-over-TCP to SFU).
        # Serves clients on networks where all UDP is blocked. Must be opened
        # in the firewall and NAT-forwarded at the edge router independently
        # of the Cloudflare tunnel (media never transits Cloudflare).
        tcp_port = 7881;

        # RTC IP Configuration:
        # LiveKit 1.9.4 uses the 'ips' block to control advertised candidates.
        ips = {
          # Explicitly include the LAN IP for direct internal routing.
          # Note: LiveKit expects CIDR notation here.
          includes = [
            "10.0.1.7/32"
          ];
        };
        # Dynamically discover the WAN IP via STUN.
        # This is more robust than hardcoding in NAT environments where the
        # public IP might be dynamic or subject to Hairpin NAT behavior.
        use_external_ip = true;
      };

      # Built-in TURN server:
      # Provides ICE relay for clients behind symmetric NAT or ISPs that block UDP.
      # Coturn is not used — LiveKit TURN is the sole TURN/STUN relay for this stack.
      # Reuses the ports previously reserved for Coturn (already open at the edge):
      #   TURN/UDP:  3478   (plain relay / STUN)
      #   TURNS/TLS: 5349   (TLS relay — same port as legacy coturn)
      # LiveKit handles TLS directly using the domain cert rendered by vault-agent.
      # Credentials are HMAC-generated per-session; use_external_ip discovers WAN IP via STUN.
      turn = {
        enabled = true;
        domain = rtcDomain;
        tls_port = 5349;
        udp_port = 3478;
        cert_file = "/run/certs/turn-fullchain.pem";
        key_file = "/run/certs/turn.key";
      };
    };
  };

  # MatrixRTC Token Service:
  # Provides JWT-based authentication for clients connecting to the SFU.
  services.lk-jwt-service = {
    enable = true;
    # Keep NixOS option 'port' to satisfy module validation.
    port = 8081;
    inherit keyFile;
    # Public SFU URL returned to clients in JWT responses.
    # MUST be the public WebSocket endpoint — clients use this URL to connect
    # to the SFU. Using the internal 127.0.0.1 address would cause clients to
    # attempt connecting to their own localhost and silently fail.
    livekitUrl = "wss://${rtcDomain}/livekit/sfu";
  };

  systemd.services.lk-jwt-service = {
    # Force use of modern bind syntax by unsetting the module-provided PORT
    # and explicitly providing BIND. This avoids the 'MUST NOT be set together' error.
    environment = {
      LIVEKIT_JWT_PORT = lib.mkForce null;
      LIVEKIT_JWT_BIND = ":8081";
      # Public SFU URL — returned in /sfu/get responses so clients connect
      # through HAProxy (/livekit/sfu → 127.0.0.1:7880) rather than to
      # localhost. The LiveKit Go SDK converts wss:// to https:// for Twirp
      # API calls, which route correctly via lk_sfu_backend.
      LIVEKIT_URL = "wss://${rtcDomain}/livekit/sfu";
      LIVEKIT_FULL_ACCESS_HOMESERVERS = matrixDomain;
      # Internal Discovery: Point directly to the local well-known server.
      # This ensures lk-jwt-service can resolve homeserver details even if
      # HAProxy or external DNS are experiencing issues.
      LIVEKIT_WELL_KNOWN_URL = "http://127.0.0.1:8083";
    };
  };
}
