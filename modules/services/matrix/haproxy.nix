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

        # Modern SSL defaults
        ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets

      defaults
        mode    http
        log     global
        timeout connect 5s
        timeout client  600s
        timeout server  600s
        timeout tunnel  3600s
        option  forwardfor
        option  http-server-close

        # Traceability & Observability:
        # Custom log format incorporating Cloudflare edge metadata (Ray ID, Real IP, Country).
        log-format "%ci:%cp [%tr] %ft %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs %{+Q}r %[var(txn.cf_ray)] %[var(txn.cf_ip)] %[var(txn.cf_country)]"

      # Matrix Ingress:
      # Unified entry point for all stack components. Handles OIDC routing,
      # media signaling, and static asset distribution.
      frontend matrix_ingress
        # Public entry and local secure tunnel entry
        bind *:443 ssl crt /run/certs/haproxy.pem
        bind 127.0.0.1:8443 ssl crt /run/certs/haproxy.pem

        # Edge Metadata Processing:
        # Capture and propagate Cloudflare headers to internal backends for end-to-end traceability.
        http-request set-var(txn.cf_ray)     hdr(CF-Ray)
        http-request set-var(txn.cf_ip)      hdr(CF-Connecting-IP)
        http-request set-var(txn.cf_country) hdr(CF-IPCountry)

        # Source Identity:
        # Treat the Cloudflare connecting IP as the source for all internal tracking and ACLs.
        http-request set-src hdr(CF-Connecting-IP) if { hdr(CF-Connecting-IP) -m found }

        http-request set-header X-Forwarded-For %[hdr(CF-Connecting-IP)] if { hdr(CF-Connecting-IP) -m found }
        http-request set-header X-Cloudflare-Ray %[hdr(CF-Ray)] if { hdr(CF-Ray) -m found }
        http-request set-header X-Cloudflare-Country %[hdr(CF-IPCountry)] if { hdr(CF-IPCountry) -m found }

        # Component Routing Logic:
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

      # System Health & Metrics:
      # Exposes HAProxy stats and Prometheus metrics on a dedicated port.
      # TLS is enforced; access restricted to trusted administrative subnets.
      frontend stats
        bind *:8404 ssl crt /run/certs/haproxy.pem
        stats   enable
        stats   show-legends
        stats   show-modules
        stats   uri /stats
        stats   admin if { src ${lib.concatStringsSep " " adminIPs} }
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
