{
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
    port = 8081;
    inherit keyFile;
    # Point directly to the local SFU instead of through HAProxy.
    # ws:// protocol satisfies module validation for internal plaintext connection.
    livekitUrl = "ws://127.0.0.1:7880";
  };

  systemd.services = {
    lk-jwt-service.serviceConfig.Environment = [
      "LIVEKIT_URL=ws://127.0.0.1:7880"
      "LIVEKIT_FULL_ACCESS_HOMESERVERS=${matrixDomain}"
    ];
  };
}
