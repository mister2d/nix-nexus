{
  pkgs,
  matrixDomain,
  rtcDomain,
  ...
}:
let
  # Client Configuration:
  # Generates the element-web config.json to ensure users are automatically
  # routed to the fleet homeserver with secure defaults.
  #
  # element_call.url overrides the default (https://call.element.io) so
  # Element Web uses the self-hosted Element Call instance. Without this,
  # Element Web either routes to the public call.element.io or falls back
  # to Jitsi for group calls.
  #
  # element_call.use_exclusively disables the legacy Jitsi VoIP stack and
  # makes Element Call (MatrixRTC / MSC3401) the sole calling backend.
  #
  # Note: standalone call.${callDomain} login (username/password) is a
  # limitation of Element Call 0.11.1 — it does not support native OIDC
  # in standalone mode. For authenticated users this is irrelevant: Element
  # Web embeds Element Call as a widget and passes the access token via the
  # Widget API (MSC2764), so no separate OIDC flow is required for calls.
  elementConfig = pkgs.writeText "element-config.json" (
    builtins.toJSON {
      default_server_config = {
        "m.homeserver" = {
          base_url = "https://${matrixDomain}";
          server_name = matrixDomain;
        };
        # MatrixRTC focus discovery — fallback for some Element versions that
        # don't query the unstable discovery endpoint correctly.
        "org.matrix.msc4143.rtc_foci" = [
          {
            type = "livekit";
            livekit_service_url = "https://${rtcDomain}/livekit/jwt";
            livekit_alias = matrixDomain;
          }
          {
            type = "rtc_transports";
            livekit_service_url = "https://${rtcDomain}/livekit/jwt";
            livekit_alias = matrixDomain;
          }
          {
            type = "foci";
            livekit_service_url = "https://${rtcDomain}/livekit/jwt";
            livekit_alias = matrixDomain;
          }
          {
            type = "transports";
            livekit_service_url = "https://${rtcDomain}/livekit/jwt";
            livekit_alias = matrixDomain;
          }
        ];
        "org.matrix.msc4143.rtc_web_v1" = {
          livekit = {
            preferred_url = "https://${rtcDomain}/livekit/sfu";
          };
        };
        "org.matrix.msc4140.rtc_v1" = {
          livekit = {
            preferred_url = "https://${rtcDomain}/livekit/sfu";
          };
        };
        "org.matrix.msc3861.matrix_rtc" = {
          "urn:matrix:org.matrix.msc3861:livekit" = {
            preferred_url = "https://${rtcDomain}/livekit/sfu";
          };
        };
      };
      disable_custom_urls = true;
      disable_guests = true;
      brand = "Element";

      # Explicitly enable the MatrixRTC video room features
      features = {
        feature_video_rooms = true;
        feature_group_calls = true;
        feature_element_call_video_rooms = true;
      };

      element_call = {
        url = "https://${rtcDomain}";
        use_exclusively = true;
      };
    }
  );

  elementWeb = pkgs.element-web;
in
{
  # Static Asset Distribution:
  # Serves the Element Web client. A symlink forest is created at runtime
  # to merge the static assets with the dynamically generated configuration.
  systemd.services.element-web = {
    description = "Element Web static server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStartPre = pkgs.writeShellScript "prep-element-web" ''
        mkdir -p /run/element-web
        ln -sf ${elementWeb}/* /run/element-web/
        ln -sf ${elementConfig} /run/element-web/config.json
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
