{
  pkgs,
  matrixDomain,
  rtcDomain,
  ...
}:
let
  # Bundled Widget Focus Config:
  # Element Web 1.12.x always serves the embedded Element Call widget from its
  # own origin (element.novuscotia.com/widgets/element-call/) regardless of the
  # element_call.url setting. This means the widget reads config.json from
  # /widgets/element-call/config.json — not from the root config.json and not
  # from the external element-call instance at rtcDomain.
  #
  # The element-web package ships a minimal config.json containing only
  # matrix_rtc_session timing parameters with no focus configuration. Without
  # overriding this file, Element Call cannot discover LiveKit and throws
  # MISSING_MATRIX_RTC_FOCUS on call initiation. Joining an existing call
  # (started by Element X) still works because the focus is read from the
  # m.call.member room state event rather than from discovery.
  #
  # This config merges the upstream timing parameters with the focus config so
  # both are present for the bundled widget.
  widgetCallConfig = pkgs.writeText "element-call-widget-config.json" (
    builtins.toJSON {
      # Preserve upstream session timing parameters.
      matrix_rtc_session = {
        delayed_leave_event_delay_ms = 90000;
        delayed_leave_event_restart_local_timeout_ms = 10000;
        delayed_leave_event_restart_ms = 4000;
        membership_event_expiry_ms = 7200000;
        network_error_retry_ms = 100;
        wait_for_key_rotation_ms = 5000;
      };
      # Focus discovery — read by Element Call when no focus is provided
      # via room state or Widget API. Mirrors the well-known and standalone
      # Element Call config so all three discovery paths converge.
      default_server_config = {
        "m.homeserver" = {
          base_url = "https://${matrixDomain}";
          server_name = matrixDomain;
        };
        "org.matrix.msc4143.rtc_foci" = [
          {
            type = "livekit";
            livekit_service_url = "https://${rtcDomain}/livekit/jwt";
            livekit_alias = matrixDomain;
          }
        ];
        "matrix_rtc" = {
          foci = [
            {
              type = "livekit";
              livekit_service_url = "https://${rtcDomain}/livekit/jwt";
              livekit_alias = matrixDomain;
            }
          ];
        };
      };
    }
  );

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
          foci = [
            {
              type = "livekit";
              livekit_service_url = "https://${rtcDomain}/livekit/jwt";
              livekit_alias = matrixDomain;
            }
          ];
          "urn:matrix:org.matrix.msc3861:livekit" = {
            preferred_url = "https://${rtcDomain}/livekit/sfu";
          };
        };
        "matrix_rtc" = {
          foci = [
            {
              type = "livekit";
              livekit_service_url = "https://${rtcDomain}/livekit/jwt";
              livekit_alias = matrixDomain;
            }
          ];
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

        # Override the bundled Element Call widget config.
        # element-web ships widgets/element-call/ as a directory in the Nix store,
        # so the glob above creates a single symlink for the entire widgets/ dir.
        # Files inside a symlinked directory cannot be individually overridden, so
        # we replace the widgets/element-call symlink chain with a real directory
        # containing per-file symlinks, then inject our focus-aware config.json.
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
