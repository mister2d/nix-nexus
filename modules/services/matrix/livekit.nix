{
  pkgs,
  matrixDomain,
  ...
}:
let
  keyFile = "/run/livekit.key";
in
{
  services.livekit = {
    enable = true;
    inherit keyFile;
    settings = {
      port = 7880;
      # Authentication Policy:
      # Prevent unauthenticated SFU room creation.
      room.auto_create = false;

      rtc = {
        # Discover public IP via STUN for ICE candidates.
        # Without this, LiveKit advertises the container's internal veth IP
        # and WebRTC media cannot reach it from external clients.
        use_external_ip = true;
        # UDP port range for WebRTC media. Must stay within the range
        # opened in hosts/avina/default.nix allowedUDPPortRanges (50100-50200).
        port_range_start = 50100;
        port_range_end = 50200;
        # TCP fallback for RTC media (not TURN — direct RTP-over-TCP to SFU).
        # Serves clients on networks where all UDP is blocked. Must be opened
        # in the firewall and NAT-forwarded at the edge router independently
        # of the Cloudflare tunnel (media never transits Cloudflare).
        tcp_port = 7881;
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
        domain = matrixDomain;
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
    livekitUrl = "wss://${matrixDomain}/livekit/sfu";
  };

  systemd.services = {
    # Key Management:
    # Automated, idempotent generation of SFU access keys.
    livekit-key = {
      before = [
        "lk-jwt-service.service"
        "livekit.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        livekit
        coreutils
        gawk
      ];
      script = ''
        echo "lk-jwt-service: $(livekit-server generate-keys | tail -1 | awk '{print $3}')" \
          > "${keyFile}"
      '';
      serviceConfig.Type = "oneshot";
      unitConfig.ConditionPathExists = "!${keyFile}";
    };

    lk-jwt-service.serviceConfig.Environment = [
      "LIVEKIT_URL=wss://${matrixDomain}/livekit/sfu"
      "LIVEKIT_FULL_ACCESS_HOMESERVERS=${matrixDomain}"
    ];
  };
}
