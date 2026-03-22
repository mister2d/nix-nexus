{
  pkgs,
  matrixDomain,
  ...
}:
let
  # Client Configuration:
  # Generates the element-web config.json to ensure users are automatically
  # routed to the fleet homeserver with secure defaults.
  elementConfig = pkgs.writeText "element-config.json" (
    builtins.toJSON {
      default_server_config = {
        "m.homeserver" = {
          base_url = "https://${matrixDomain}";
          server_name = matrixDomain;
        };
      };
      disable_custom_urls = true;
      disable_guests = true;
      brand = "Element";
    }
  );

  elementWeb = pkgs.element-web.override {
    conf = elementConfig;
  };
in
{
  # Static Asset Distribution:
  # Serves the Element Web client via a lightweight static server.
  # Ingress is managed by the fleet HAProxy.
  systemd.services.element-web = {
    description = "Element Web static server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd ${elementWeb} --port 8082 --addr 127.0.0.1";
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      CapabilityBoundingSet = "";
    };
  };
}
