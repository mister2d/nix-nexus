{
  pkgs,
  lib,
  matrixDomain,
  ...
}:
let
  adminIPs = [
    "127.0.0.1"
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
  ];
  # wellKnownDir = "/run/avina-wellknown";
  wellKnownConfig = pkgs.writeTextDir "matrix/client" (
    builtins.toJSON {
      "m.homeserver" = {
        base_url = "https://${matrixDomain}";
      };
      "org.matrix.msc3575.proxy" = {
        url = "https://${matrixDomain}";
      };
      "org.matrix.msc4143.rtc_foci" = [
        {
          type = "livekit";
          livekit_service_url = "https://${matrixDomain}/livekit/jwt";
        }
      ];
    }
  );
in
{
  # Well-known server on 8083
  systemd.services.avina-wellknown = {
    description = "Matrix well-known static server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd ${wellKnownConfig} --port 8083 --addr 127.0.0.1";
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      CapabilityBoundingSet = "";
    };
  };

  services.haproxy = {
    enable = true;
    config = ''
      global
        maxconn 4096
        stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners

      defaults
        mode    http
        timeout connect 5s
        timeout client  600s
        timeout server  600s
        timeout tunnel  3600s
        option  forwardfor
        option  http-server-close

      # ── Matrix ingress (from cloudflared) ────────────────────────────────────
      frontend matrix_ingress
        bind 127.0.0.1:8080

        # MSC3861 auth endpoint routing
        acl is_mas_login   path_beg /_matrix/client/v3/login
        acl is_mas_login   path_beg /_matrix/client/r0/login
        acl is_mas_logout  path_beg /_matrix/client/v3/logout
        acl is_mas_logout  path_beg /_matrix/client/r0/logout
        acl is_mas_refresh path_beg /_matrix/client/v3/refresh
        acl is_mas_auth    path_beg /auth
        acl is_mas_oidc    path_beg /_mas
        acl is_lk_jwt      path_beg /livekit/jwt
        acl is_lk_sfu      path_beg /livekit/sfu
        acl is_matrix      path_beg /_matrix
        acl is_synapse     path_beg /_synapse
        acl is_wellknown   path_beg /.well-known

        use_backend mas_backend       if is_mas_login or is_mas_logout or is_mas_refresh or is_mas_auth or is_mas_oidc
        use_backend lk_jwt_backend    if is_lk_jwt
        use_backend lk_sfu_backend    if is_lk_sfu
        use_backend wellknown_backend if is_wellknown
        use_backend synapse_backend   if is_matrix or is_synapse
        default_backend element_backend

      # ── Stats and Prometheus metrics ──────────────────────────────────────────
      # Binds on all interfaces on the designated stats port with TLS.
      # /run/certs/haproxy.pem is rendered by consul-template from Vault KV.
      frontend stats
        bind *:8404 ssl crt /run/certs/haproxy.pem
        option  http-use-htx
        stats   enable
        stats   show-legends
        stats   show-modules
        stats   uri /stats
        # Admin level for RFC-1918 + loopback source addresses
        stats   admin if { src ${lib.concatStringsSep " " adminIPs} }
        # Prometheus metrics endpoint
        http-request use-service prometheus-exporter if { path /metrics }

      backend synapse_backend
        server synapse 127.0.0.1:8008

      backend mas_backend
        server mas 127.0.0.1:8181

      backend lk_jwt_backend
        server lk_jwt 127.0.0.1:8081

      backend lk_sfu_backend
        option http-server-close
        server lk_sfu 127.0.0.1:7880

      backend wellknown_backend
        server wellknown 127.0.0.1:8083

      backend element_backend
        server element 127.0.0.1:8082
    '';
  };
}
