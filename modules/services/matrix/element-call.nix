{
  pkgs,
  matrixDomain,
  ...
}:
let
  elementCallConfig = pkgs.writeText "element-call-config.json" (
    builtins.toJSON {
      default_server_config = {
        "m.homeserver" = {
          base_url = "https://${matrixDomain}";
          server_name = matrixDomain;
        };
      };
      livekit_service_url = "https://${matrixDomain}/livekit/jwt";
      # Element Call specific settings
      brand = "Element Call";
    }
  );

  # The element-call package provides the static assets.
  # We override it to include our custom config if the package supports it,
  # otherwise we'll just serve the config alongside it.
  elementCall = pkgs.element-call.override {
    # Check nixpkgs for exact override pattern if needed.
    # Usually we can just drop the config.json into the folder or use a wrapper.
  };
in
{
  # Simple static server for Element Call on port 8084
  systemd.services.element-call = {
    description = "Element Call static server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      # We serve the element-call package, but we must ensure config.json is present.
      # A simple way is to create a symlink forest or just serve from a combined directory.
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
