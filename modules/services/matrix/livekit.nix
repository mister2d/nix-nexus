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
      };

      # Built-in TURN server:
      # Provides ICE relay for clients behind symmetric NAT or ISPs that block UDP.
      # Uses separate ports from Coturn (which serves legacy Matrix VoIP TURN):
      #   Coturn: UDP/TCP 3478, TURNS 5349
      #   LiveKit: TURN/UDP 3479, TURNS/TLS 5350
      # LiveKit handles TLS directly using the same cert/key as coturn (same domain).
      # Credentials are HMAC-generated per-session; credential_lifetime controls TTL.
      turn = {
        enabled = true;
        domain = matrixDomain;
        tls_port = 5350;
        udp_port = 3479;
        cert_file = "/run/certs/coturn-fullchain.pem";
        key_file = "/run/certs/coturn.key";
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
