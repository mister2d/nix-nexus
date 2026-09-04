_: {
  flake.modules.nixos.services-matrix =
    {
      lib,
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
            # Advertise the LAN IP directly. use_external_ip = true is intentionally
            # absent: it would cause LiveKit to discover the WAN IP via STUN and use
            # it for both ICE host candidates and TURN relay allocation. The WAN IP
            # does not exist as a local interface on avina, so TURN relay allocation
            # fails silently (no relay candidates are produced), and host candidates
            # at the WAN IP are unreachable internally without hairpin NAT.
            # Split horizon DNS resolves matrix-rtc.novuscotia.com to 10.0.1.7 for
            # internal clients, so advertising 10.0.1.7 directly gives all LAN and
            # Tailscale-subnet clients a valid host candidate and working TURN relay.
            ips = {
              includes = [
                "10.0.1.7/32"
              ];
            };
          };

          # Built-in TURN server:
          # Provides ICE relay for clients behind symmetric NAT or ISPs that block UDP.
          # Coturn is not used — LiveKit TURN is the sole TURN/STUN relay for this stack.
          # Reuses the ports previously reserved for Coturn (already open at the edge):
          #   TURN/UDP:  3478   (plain relay / STUN)
          #   TURNS/TLS: 5349   (TLS relay — same port as legacy coturn)
          # LiveKit handles TLS directly using the domain cert rendered by vault-agent.
          # Credentials are HMAC-generated per-session.
          # use_external_ip is intentionally absent (same reasoning as rtc above): the
          # TURN relay advertises 10.0.1.7 as the relay address, which is reachable by
          # all LAN and Tailscale-subnet clients via split-horizon DNS.
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
        # synapse, and MAS already carry this ordering; this one did not.
        after = [ "vault-agent-init.service" ];
        wants = [ "vault-agent-init.service" ];

        # Force use of modern bind syntax by unsetting the module-provided PORT
        # and explicitly providing BIND. This avoids the 'MUST NOT be set together' error.
        environment = {
          LIVEKIT_JWT_PORT = lib.mkForce null;
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
