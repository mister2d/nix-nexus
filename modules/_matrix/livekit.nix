{ config, lib, ... }:
let
  cfg = config.matrix;
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
        auto_create = false;
        empty_timeout = 300;
        enabled_codecs = [
          { mime = "video/h264"; }
          { mime = "audio/opus"; }
        ];
      };

      rtc = {
        port_range_start = 50100;
        port_range_end = 50200;
        tcp_port = 7881;
        ips = {
          includes = [ "10.0.1.7/32" ];
        };
      };

      turn = {
        enabled = true;
        domain = cfg.rtcDomain;
        tls_port = 5349;
        udp_port = 3478;
        cert_file = "/run/certs/turn-fullchain.pem";
        key_file = "/run/certs/turn.key";
      };
    };
  };

  # MatrixRTC Token Service:
  services.lk-jwt-service = {
    enable = true;
    port = 8081;
    inherit keyFile;
    livekitUrl = "wss://${cfg.rtcDomain}/livekit/sfu";
  };

  systemd.services.lk-jwt-service = {
    environment = {
      LIVEKIT_JWT_PORT = lib.mkForce null;
      LIVEKIT_JWT_BIND = ":8081";
      LIVEKIT_URL = "wss://${cfg.rtcDomain}/livekit/sfu";
      LIVEKIT_FULL_ACCESS_HOMESERVERS = cfg.matrixDomain;
      # Internal Discovery: Point directly to the local well-known server.
      LIVEKIT_WELL_KNOWN_URL = "http://127.0.0.1:8083";
    };
  };
}
