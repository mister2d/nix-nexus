# Merged into: flake.modules.nixos.services-matrix
# Configures: the LiveKit SFU, its built-in TURN server, and the JWT token service.
# Imported by: hosts/avina/default.nix (avina-default).
_: {
  flake.modules.nixos.services-matrix =
    {
      matrixDomain,
      rtcDomain,
      ...
    }:
    let
      # Key rendered by Vault Agent from turn_shared_secret.
      keyFile = "/run/vault-secrets/livekit.key";

      livekitPort = 7880; # LiveKit HTTP/WebSocket port
      rtcPortRangeStart = 50100; # WebRTC media UDP port range start
      rtcPortRangeEnd = 50200; # WebRTC media UDP port range end
      rtcTcpPort = 7881; # WebRTC media TCP fallback port
      turnTlsPort = 5349; # TURN over TLS port
      turnUdpPort = 3478; # TURN over UDP port
      jwtServicePort = 8081; # lk-jwt-service port
      wellKnownPort = 8083; # local well-known server port
    in
    {
      services.livekit = {
        enable = true;
        inherit keyFile;
        settings = {
          port = livekitPort;
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
            port_range_start = rtcPortRangeStart;
            port_range_end = rtcPortRangeEnd;
            # TCP fallback for RTC media.
            tcp_port = rtcTcpPort;

            # RTC IP Configuration:
            # Advertise the LAN IP directly. use_external_ip = true stays absent.
            # That setting would make LiveKit discover the WAN IP via STUN.
            # It would then use the WAN IP for ICE host candidates and for
            # TURN relay allocation.
            # The WAN IP does not exist as a local interface on avina.
            # TURN relay allocation then fails silently, producing no relay
            # candidates. Host candidates at the WAN IP become unreachable
            # internally, since avina has no hairpin NAT.
            # Split horizon DNS resolves matrix-rtc.novuscotia.com to 10.0.1.7
            # for internal clients. Advertising 10.0.1.7 directly gives every
            # LAN and Tailscale-subnet client a valid host candidate and a
            # working TURN relay.
            ips = {
              includes = [
                "10.0.1.7/32"
              ];
            };
          };

          # Built-in TURN server:
          # Provides ICE relay for clients behind symmetric NAT or ISPs that block UDP.
          # LiveKit TURN is the sole TURN/STUN relay for this stack. Coturn is not used.
          # The edge firewall opens these ports for TURN:
          #   TURN/UDP:  3478   (plain relay / STUN)
          #   TURNS/TLS: 5349   (TLS relay)
          # LiveKit handles TLS directly using the domain cert rendered by vault-agent.
          # Credentials are HMAC-generated per-session.
          # use_external_ip is absent. The TURN relay advertises 10.0.1.7 as the
          # relay address, reachable by all LAN and Tailscale-subnet clients via
          # split-horizon DNS.
          turn = {
            enabled = true;
            domain = rtcDomain;
            tls_port = turnTlsPort;
            udp_port = turnUdpPort;
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
        port = jwtServicePort;
        inherit keyFile;
        # Public SFU URL returned to clients in JWT responses.
        # MUST be the public WebSocket endpoint — clients use this URL to connect
        # to the SFU. Using the internal 127.0.0.1 address would cause clients to
        # attempt connecting to their own localhost and silently fail.
        livekitUrl = "wss://${rtcDomain}/livekit/sfu";
      };

      systemd.services.lk-jwt-service = {
        # LoadCredential reads /run/vault-secrets/livekit.key at unit start, so
        # the unit must not start before vault-agent has rendered it. livekit,
        # synapse, and MAS carry the same ordering.
        after = [ "vault-agent-init.service" ];
        wants = [ "vault-agent-init.service" ];

        # lk-jwt-service derives LIVEKIT_JWT_BIND from the port option.
        # This declares the same value directly for clarity.
        environment = {
          LIVEKIT_JWT_BIND = ":${toString jwtServicePort}";
          # Public SFU URL — returned in /sfu/get responses so clients connect
          # through HAProxy (/livekit/sfu → 127.0.0.1:7880) rather than to
          # localhost. The LiveKit Go SDK converts wss:// to https:// for Twirp
          # API calls, which route correctly via lk_sfu_backend.
          LIVEKIT_URL = "wss://${rtcDomain}/livekit/sfu";
          LIVEKIT_FULL_ACCESS_HOMESERVERS = matrixDomain;
          # Internal Discovery: Point directly to the local well-known server.
          # This ensures lk-jwt-service can resolve homeserver details even if
          # HAProxy or external DNS are experiencing issues.
          LIVEKIT_WELL_KNOWN_URL = "http://127.0.0.1:${toString wellKnownPort}";
        };
      };
    };
}
