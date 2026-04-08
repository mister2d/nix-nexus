{ config, pkgs, ... }:
let
  cfg = config.matrix;
  elementCallConfig = pkgs.writeText "element-call-config.json" (
    builtins.toJSON {
      default_server_config = {
        "m.homeserver" = {
          base_url = "https://${cfg.matrixDomain}";
          server_name = cfg.matrixDomain;
        };
        "org.matrix.msc4143.rtc_foci" = [
          { type = "livekit"; livekit_service_url = "https://${cfg.rtcDomain}/livekit/jwt"; livekit_alias = cfg.matrixDomain; }
          { type = "rtc_transports"; livekit_service_url = "https://${cfg.rtcDomain}/livekit/jwt"; livekit_alias = cfg.matrixDomain; }
          { type = "foci"; livekit_service_url = "https://${cfg.rtcDomain}/livekit/jwt"; livekit_alias = cfg.matrixDomain; }
          { type = "transports"; livekit_service_url = "https://${cfg.rtcDomain}/livekit/jwt"; livekit_alias = cfg.matrixDomain; }
        ];
        "org.matrix.msc4143.rtc_web_v1" = { livekit = { preferred_url = "https://${cfg.rtcDomain}/livekit/sfu"; }; };
        "org.matrix.msc4140.rtc_v1" = { livekit = { preferred_url = "https://${cfg.rtcDomain}/livekit/sfu"; }; };
        "org.matrix.msc3861.matrix_rtc" = {
          foci = [
            { type = "livekit"; livekit_service_url = "https://${cfg.rtcDomain}/livekit/jwt"; livekit_alias = cfg.matrixDomain; }
          ];
          "urn:matrix:org.matrix.msc3861:livekit" = { preferred_url = "https://${cfg.rtcDomain}/livekit/sfu"; };
        };
        "matrix_rtc" = {
          foci = [
            { type = "livekit"; livekit_service_url = "https://${cfg.rtcDomain}/livekit/jwt"; livekit_alias = cfg.matrixDomain; }
          ];
          "urn:matrix:org.matrix.msc3861:livekit" = { preferred_url = "https://${cfg.rtcDomain}/livekit/sfu"; };
        };
      };
    }
  );

  elementCall = pkgs.element-call;
in
{
  systemd.services.element-call = {
    description = "Element Call static server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStartPre = pkgs.writeShellScript "prep-element-call" ''
        mkdir -p /run/element-call
        ln -sf ${elementCall}/* /run/element-call/
        ln -sf ${elementCallConfig} /run/element-call/config.json
      '';
      ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd /run/element-call --port 8084 --addr 127.0.0.1";
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateTmp = true;
      RuntimeDirectory = "element-call";
      ProtectSystem = "strict";
      ProtectHome = true;
      CapabilityBoundingSet = "";
    };
  };
}
