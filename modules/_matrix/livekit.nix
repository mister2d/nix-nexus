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
        # Clients behind strict NAT reach these via Coturn TURN relay
        # (Coturn can relay to the public IP on these ports).
        port_range_start = 50100;
        port_range_end = 50200;
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
