{
  pkgs,
  matrixDomain,
  coturnRealm,
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

      # Media Relay Policy:
      # Force all WebRTC traffic through the fleet TURN relay to ensure
      # connectivity across restrictive networks and maintain a minimal footprint.
      turn = {
        enabled = true;
        domain = coturnRealm;
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

    livekit.serviceConfig.EnvironmentFile = "/run/secrets/coturn-secret-env";

    lk-jwt-service.serviceConfig.Environment = [
      "LIVEKIT_URL=wss://${matrixDomain}/livekit/sfu"
      "LIVEKIT_FULL_ACCESS_HOMESERVERS=${matrixDomain}"
    ];
  };
}
