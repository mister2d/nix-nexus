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
