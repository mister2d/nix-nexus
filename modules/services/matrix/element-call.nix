{
  pkgs,
  matrixDomain,
  ...
}:
let
  # Client Configuration:
  # Element Call requires explicit registration of the LiveKit JWT service
  # to handle MatrixRTC media signaling.
  elementCallConfig = pkgs.writeText "element-call-config.json" (
    builtins.toJSON {
      default_server_config = {
        "m.homeserver" = {
          base_url = "https://${matrixDomain}";
          server_name = matrixDomain;
        };
      };
      livekit_service_url = "https://${matrixDomain}/livekit/jwt";
      brand = "Element Call";
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
}
