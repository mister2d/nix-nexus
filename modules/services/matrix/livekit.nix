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
      # Mandatory: prevents unauthenticated room creation
      room.auto_create = false;

      # TURN configuration for media relay
      turn = {
        enabled = true;
        domain = coturnRealm;
        # shared_secret should be passed via environment if not supported in settings
      };
    };
  };

  services.lk-jwt-service = {
    enable = true;
    port = 8081;
    inherit keyFile;
    livekitUrl = "wss://${matrixDomain}/livekit/sfu";
  };

  systemd.services = {
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
    # The file should contain: LIVEKIT_TURN_SHARED_SECRET=<secret>

    lk-jwt-service.serviceConfig.Environment = [
      "LIVEKIT_URL=wss://${matrixDomain}/livekit/sfu"
      "LIVEKIT_FULL_ACCESS_HOMESERVERS=${matrixDomain}"
    ];
  };
}
