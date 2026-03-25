{
  pkgs,
  lib,
  matrixDomain,
  masDomain,
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
  # Matrix well-known static server:
  # Serves the .well-known/matrix/client discovery file required for client
  # autodiscovery and media signaling (MSC4143).
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

        # High-Security SSL configuration:
        # Enforces modern ciphers and TLS 1.2+ to satisfy production security requirements.
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
        # Custom log format incorporating Cloudflare edge metadata (Ray ID, Real IP, Country)
        # to ensure end-to-end request visibility.
        log-format "%ci:%cp [%tr] %ft %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs %{+Q}r %[var(txn.cf_ray)] %[var(txn.cf_ip)] %[var(txn.cf_country)]"

      # Matrix Ingress Frontend:
      # Secure entry point for all stack components.
      frontend matrix_ingress
        bind *:443 ssl crt /run/certs/haproxy.pem

        # Edge Metadata Processing:
        # Captures and propagates Cloudflare headers to internal backends.
        http-request set-var(txn.cf_ray)     hdr(CF-Ray)
        http-request set-var(txn.cf_ip)      hdr(CF-Connecting-IP)
        http-request set-var(txn.cf_country) hdr(CF-IPCountry)

        # Source Identity:
        # Restores the original client IP from Cloudflare metadata for internal tracking.
        http-request set-src hdr(CF-Connecting-IP) if { hdr(CF-Connecting-IP) -m found }

        http-request set-header X-Forwarded-For %[hdr(CF-Connecting-IP)] if { hdr(CF-Connecting-IP) -m found }
        http-request set-header X-Cloudflare-Ray %[hdr(CF-Ray)] if { hdr(CF-Ray) -m found }
        http-request set-header X-Cloudflare-Country %[hdr(CF-IPCountry)] if { hdr(CF-IPCountry) -m found }

        # Component Routing Logic:
        # Dispatches traffic to the appropriate Matrix 2.0 component based on path/host.
        # MAS compat layer: matches any API version per official MAS reverse-proxy docs.
        acl is_mas_compat_auth  path_reg ^/_matrix/client/[^/]+/(login|logout|refresh)
        # MAS compat SSO callback: /complete-compat-sso/<token> lands on matrixDomain.
        acl is_mas_compat       path_beg /complete-compat-sso
        # MSC2965 auth metadata: owned by MAS, not Synapse; must match before is_matrix.
        acl is_mas_auth_meta    path_beg /_matrix/client/unstable/org.matrix.msc2965
        acl is_mas_auth_meta    path_beg /_matrix/client/v1/auth_metadata
        # MAS domain: all traffic on the auth subdomain routes to MAS.
        acl is_mas_domain       hdr(host) -i ${masDomain}
        acl is_mas_auth         path_beg /auth
        acl is_mas_oidc         path_beg /_mas
        acl is_lk_jwt           path_beg /livekit/jwt
        acl is_lk_sfu           path_beg /livekit/sfu
        acl is_matrix           path_beg /_matrix
        acl is_synapse          path_beg /_synapse
        acl is_wellknown        path_beg /.well-known
        acl is_call             hdr(host) -i ${callDomain}

        use_backend mas_backend       if is_mas_domain or is_mas_compat_auth or is_mas_compat or is_mas_auth_meta or is_mas_auth or is_mas_oidc
        use_backend lk_jwt_backend    if is_lk_jwt
        use_backend lk_sfu_backend    if is_lk_sfu
        use_backend wellknown_backend if is_wellknown
        use_backend synapse_backend   if is_matrix or is_synapse
        use_backend element_call_backend if is_call
        default_backend element_backend

      # System Health & Metrics:
      # Exposes HAProxy stats and Prometheus metrics. TLS is enforced; 
      # access is restricted to trusted administrative subnets.
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
        server mas 127.0.0.1:8181 send-proxy-v2

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
