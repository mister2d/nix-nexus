{
  pkgs,
  lib,
  matrixDomain,
  callDomain,
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
        log stdout format raw local0

      defaults
        mode    http
        log     global
        option  httplog
        timeout connect 5s
        timeout client  600s
        timeout server  600s
        timeout tunnel  3600s
        option  forwardfor
        option  http-server-close

        # Custom log format for observability including Cloudflare headers
        # Reference: https://developers.cloudflare.com/fundamentals/reference/http-headers/
        log-format "%ci:%cp [%tr] %ft %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs %{+Q}r %[var(txn.cf_ray)] %[var(txn.cf_ip)] %[var(txn.cf_country)]"

      # ── Matrix ingress (from cloudflared) ────────────────────────────────────
      frontend matrix_ingress
        bind 127.0.0.1:8080

        # Capture Cloudflare headers for observability
        http-request set-var(txn.cf_ray)     hdr(CF-Ray)
        http-request set-var(txn.cf_ip)      hdr(CF-Connecting-IP)
        http-request set-var(txn.cf_country) hdr(CF-IPCountry)

        # Secure awareness: Use CF-Connecting-IP as the source IP for internal ACLs and tracking
        # This allows stats/metrics and other logic to see the real client IP.
        http-request set-src hdr(CF-Connecting-IP) if { hdr(CF-Connecting-IP) -m found }

        # Pass Cloudflare headers to backends for application-level observability
        http-request set-header X-Forwarded-For %[hdr(CF-Connecting-IP)] if { hdr(CF-Connecting-IP) -m found }
        http-request set-header X-Cloudflare-Ray %[hdr(CF-Ray)] if { hdr(CF-Ray) -m found }
        http-request set-header X-Cloudflare-Country %[hdr(CF-IPCountry)] if { hdr(CF-IPCountry) -m found }

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
        acl is_call        hdr(host) -i ${callDomain}

        use_backend mas_backend       if is_mas_login or is_mas_logout or is_mas_refresh or is_mas_auth or is_mas_oidc
        use_backend lk_jwt_backend    if is_lk_jwt
        use_backend lk_sfu_backend    if is_lk_sfu
        use_backend wellknown_backend if is_wellknown
        use_backend synapse_backend   if is_matrix or is_synapse
        use_backend element_call_backend if is_call
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

      backend element_call_backend
        server element_call 127.0.0.1:8084

      backend element_backend
        server element 127.0.0.1:8082
    '';
  };
}
