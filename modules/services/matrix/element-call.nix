# Merged into: flake.modules.nixos.services-matrix
# Configures: the Element Call static server and its client-side focus discovery config.
# Imported by: hosts/avina/default.nix (avina-default).
_: {
  flake.modules.nixos.services-matrix =
    {
      pkgs,
      matrixDomain,
      rtcDomain,
      ...
    }:
    let
      # Client Configuration:
      # Minimal config — homeserver autodiscovery only. livekit_service_url is
      # intentionally absent: upstream classifies it as a local-dev override; the
      # production discovery path is /.well-known org.matrix.msc4143.rtc_foci,
      # served statically by haproxy.nix.
      elementCallConfig = pkgs.writeText "element-call-config.json" (
        builtins.toJSON {
          default_server_config = {
            "m.homeserver" = {
              base_url = "https://${matrixDomain}";
              server_name = matrixDomain;
            };
            # MatrixRTC focus discovery — fallback for widget mode.
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
        }
      );

      elementCall = pkgs.element-call;
    in
    {
      # Static Asset Distribution:
      # Serves the Element Call client. A symlink forest is created at runtime
      # to merge the static assets with the dynamically generated configuration.
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
    };
}
