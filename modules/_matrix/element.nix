{ config, pkgs, ... }:
let
  cfg = config.matrix;
  widgetCallConfig = pkgs.writeText "element-call-widget-config.json" (
    builtins.toJSON {
      matrix_rtc_session = {
        delayed_leave_event_delay_ms = 90000;
        delayed_leave_event_restart_local_timeout_ms = 10000;
        delayed_leave_event_restart_ms = 4000;
        membership_event_expiry_ms = 7200000;
        network_error_retry_ms = 100;
        wait_for_key_rotation_ms = 5000;
      };
      default_server_config = {
        "m.homeserver" = {
          base_url = "https://${cfg.matrixDomain}";
          server_name = cfg.matrixDomain;
        };
        "org.matrix.msc4143.rtc_foci" = [
          {
            type = "livekit";
            livekit_service_url = "https://${cfg.rtcDomain}/livekit/jwt";
            livekit_alias = cfg.matrixDomain;
          }
        ];
        "matrix_rtc" = {
          foci = [
            {
              type = "livekit";
              livekit_service_url = "https://${cfg.rtcDomain}/livekit/jwt";
              livekit_alias = cfg.matrixDomain;
            }
          ];
        };
      };
    }
  );

  elementConfig = pkgs.writeText "element-config.json" (
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
      disable_custom_urls = true;
      disable_guests = true;
      brand = "Element";
      features = {
        feature_video_rooms = true;
        feature_group_calls = true;
        feature_element_call_video_rooms = true;
      };
      element_call = {
        url = "https://${cfg.rtcDomain}";
        use_exclusively = true;
      };
    }
  );

  elementWeb = pkgs.element-web;
in
{
  systemd.services.element-web = {
    description = "Element Web static server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStartPre = pkgs.writeShellScript "prep-element-web" ''
        mkdir -p /run/element-web
        ln -sf ${elementWeb}/* /run/element-web/
        ln -sf ${elementConfig} /run/element-web/config.json
        rm -f /run/element-web/widgets
        mkdir -p /run/element-web/widgets/element-call
        for f in ${elementWeb}/widgets/element-call/*; do
          ln -sf "$f" "/run/element-web/widgets/element-call/$(basename "$f")"
        done
        ln -sf ${widgetCallConfig} /run/element-web/widgets/element-call/config.json
      '';
      ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd /run/element-web --port 8082 --addr 127.0.0.1";
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateTmp = true;
      RuntimeDirectory = "element-web";
      ProtectSystem = "strict";
      ProtectHome = true;
      CapabilityBoundingSet = "";
    };
  };
}
