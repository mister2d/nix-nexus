{ config, pkgs, lib, ... }:
let
  cfg = config.matrix;
  adminIPs = [ "127.0.0.1" "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" ];

  tosContent = pkgs.writeTextDir "tos/index.html" ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Terms of Service</title>
      <style>
        body { font-family: sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; line-height: 1.6; color: #333; }
        h1 { border-bottom: 1px solid #ccc; padding-bottom: 8px; }
        h2 { margin-top: 2em; }
      </style>
    </head>
    <body>
      <h1>Terms of Service</h1>
      <p><em>Last updated: 2026-03-25</em></p>
      <h2>1. Service Description</h2>
      <p>This Matrix homeserver is a private, invite-only communication service.</p>
      <!-- ... rest of TOS ... -->
    </body>
    </html>
  '';

  wellKnownConfig = pkgs.symlinkJoin {
    name = "matrix-well-known";
    paths = [
      (pkgs.writeTextDir "matrix/client" (
        builtins.toJSON {
          "m.homeserver" = { base_url = "https://${cfg.matrixDomain}"; };
          "m.authentication" = { issuer = "https://${cfg.masDomain}/"; account = "https://${cfg.masDomain}/account"; };
          "org.matrix.msc2965.authentication" = { issuer = "https://${cfg.masDomain}/"; account = "https://${cfg.masDomain}/account"; };
          "org.matrix.msc3575.proxy" = { url = "https://${cfg.matrixDomain}"; };
          "org.matrix.msc4143.rtc_foci" = [ { type = "livekit"; livekit_service_url = "https://${cfg.rtcDomain}/livekit/jwt"; livekit_alias = cfg.matrixDomain; } ];
          "org.matrix.msc4143.rtc_web_v1" = { livekit = { preferred_url = "https://${cfg.rtcDomain}/livekit/sfu"; }; };
          "org.matrix.msc4140.rtc_focus" = { type = "livekit"; livekit_service_url = "https://${cfg.rtcDomain}/livekit/jwt"; livekit_alias = cfg.matrixDomain; };
          "org.matrix.msc4140.rtc_v1" = { livekit = { preferred_url = "https://${cfg.rtcDomain}/livekit/sfu"; }; };
          "matrix_rtc" = {
            foci = [ { type = "livekit"; livekit_service_url = "https://${cfg.rtcDomain}/livekit/jwt"; livekit_alias = cfg.matrixDomain; } ];
            "urn:matrix:org.matrix.msc3861:livekit" = { preferred_url = "https://${cfg.rtcDomain}/livekit/sfu"; };
          };
          "org.matrix.msc3861.matrix_rtc" = {
            foci = [ { type = "livekit"; livekit_service_url = "https://${cfg.rtcDomain}/livekit/jwt"; livekit_alias = cfg.matrixDomain; } ];
            "urn:matrix:org.matrix.msc3861:livekit" = { preferred_url = "https://${cfg.rtcDomain}/livekit/sfu"; };
          };
        }
      ))
      (pkgs.writeTextDir "matrix/server" (builtins.toJSON { "m.server" = "${cfg.matrixDomain}:443"; }))
    ];
  };
in
{
  systemd.services.avina-tos = {
    description = "Matrix Terms of Service static server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd ${tosContent} --port 8085 --addr 127.0.0.1";
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      CapabilityBoundingSet = "";
    };
  };

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
        log-format "%ci:%cp [%tr] %ft %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs %{+Q}r %[var(txn.cf_ray)] %[var(txn.cf_ip)] %[var(txn.cf_country)]"

      frontend matrix_ingress
        bind *:443 ssl crt /run/certs/haproxy.pem
        http-request set-var(txn.cf_ray)     hdr(CF-Ray)
        http-request set-var(txn.cf_ip)      hdr(CF-Connecting-IP)
        http-request set-var(txn.cf_country) hdr(CF-IPCountry)
        http-request set-src hdr(CF-Connecting-IP) if { hdr(CF-Connecting-IP) -m found }
        http-request set-header X-Forwarded-For %[hdr(CF-Connecting-IP)] if { hdr(CF-Connecting-IP) -m found }
        http-request set-header X-Forwarded-Proto https
        http-request set-header X-Cloudflare-Ray %[hdr(CF-Ray)] if { hdr(CF-Ray) -m found }
        http-request set-header X-Cloudflare-Country %[hdr(CF-IPCountry)] if { hdr(CF-IPCountry) -m found }

        acl is_mas_compat_auth  path_reg ^/_matrix/client/[^/]+/(login|logout|refresh)
        acl is_mas_compat       path_beg /complete-compat-sso
        acl is_mas_domain       hdr(host) -i ${cfg.masDomain}
        acl is_mas_auth         path_beg /auth
        acl is_mas_oidc         path_beg /_mas
        acl is_lk_jwt           path_beg /livekit/jwt
        acl is_lk_sfu           path_beg /livekit/sfu or path_beg /twirp/
        acl is_lk_jwt_endpoint  path /livekit/jwt/sfu/get or path_beg /livekit/sfu/get
        acl is_matrix           path_beg /_matrix
        acl is_synapse          path_beg /_synapse
        acl is_wellknown        path_beg /.well-known
        acl is_tos              path_beg /tos
        acl is_rtc_domain       hdr(host) -i ${cfg.rtcDomain}

        acl is_rtc_discovery path /_matrix/client/unstable/org.matrix.msc4143/rtc/transports
        acl is_rtc_discovery path /_matrix/client/unstable/org.matrix.msc4143/rtc/foci
        acl is_rtc_discovery path /_matrix/client/unstable/org.matrix.msc4140/rtc/transports
        acl is_rtc_discovery path /_matrix/client/v1/matrix_rtc/transports
        acl is_rtc_discovery path /_matrix/client/v1/matrix_rtc/foci
        http-request return status 204 hdr "Access-Control-Allow-Origin" "*" hdr "Access-Control-Allow-Methods" "GET, POST, OPTIONS" hdr "Access-Control-Allow-Headers" "Authorization, Content-Type, Origin, X-Requested-With" hdr "Access-Control-Expose-Headers" "Content-Type, Authorization, Origin, X-Requested-With" if is_rtc_discovery { method OPTIONS }
        http-request return status 200 content-type "application/json" hdr "Access-Control-Allow-Origin" "*" hdr "Access-Control-Allow-Methods" "GET, POST, OPTIONS" hdr "Access-Control-Allow-Headers" "Authorization, Content-Type, Origin, X-Requested-With" hdr "Access-Control-Expose-Headers" "Content-Type, Authorization, Origin, X-Requested-With" string '{"transports":[{"type":"livekit","livekit_service_url":"https://${cfg.rtcDomain}/livekit/jwt","livekit_alias":"${cfg.matrixDomain}"}],"rtc_transports":[{"type":"livekit","livekit_service_url":"https://${cfg.rtcDomain}/livekit/jwt","livekit_alias":"${cfg.matrixDomain}"}],"foci":[{"type":"livekit","livekit_service_url":"https://${cfg.rtcDomain}/livekit/jwt","livekit_alias":"${cfg.matrixDomain}"}],"org.matrix.msc4143.rtc_foci":[{"type":"livekit","livekit_service_url":"https://${cfg.rtcDomain}/livekit/jwt","livekit_alias":"${cfg.matrixDomain}"}],"matrix_rtc":{"foci":[{"type":"livekit","livekit_service_url":"https://${cfg.rtcDomain}/livekit/jwt","livekit_alias":"${cfg.matrixDomain}"}],"urn:matrix:org.matrix.msc3861:livekit":{"preferred_url":"https://${cfg.rtcDomain}/livekit/sfu"}},"org.matrix.msc3861.matrix_rtc":{"foci":[{"type":"livekit","livekit_service_url":"https://${cfg.rtcDomain}/livekit/jwt","livekit_alias":"${cfg.matrixDomain}"}],"urn:matrix:org.matrix.msc3861:livekit":{"preferred_url":"https://${cfg.rtcDomain}/livekit/sfu"}}}' if is_rtc_discovery

        http-request return status 204 hdr "Access-Control-Allow-Origin" "*" hdr "Access-Control-Allow-Methods" "GET, POST, PUT, DELETE, OPTIONS" hdr "Access-Control-Allow-Headers" "Content-Type, Origin, Authorization, X-Requested-With" hdr "Access-Control-Expose-Headers" "Content-Type, Authorization, Origin, X-Requested-With" if { path /.well-known/matrix/client } { method OPTIONS }

        use_backend mas_backend       if is_mas_domain or is_mas_compat_auth or is_mas_compat or is_mas_auth or is_mas_oidc
        use_backend element_call_backend if is_rtc_domain { path / } or is_rtc_domain { path_beg /assets } or is_rtc_domain { path /config.json } or is_rtc_domain { path /manifest.json }
        use_backend lk_jwt_backend    if is_lk_jwt_endpoint
        use_backend lk_sfu_backend    if is_lk_sfu
        use_backend lk_jwt_backend    if is_lk_jwt
        use_backend wellknown_backend if is_wellknown
        use_backend tos_backend       if is_tos
        use_backend synapse_backend   if is_matrix or is_synapse
        use_backend element_call_backend if is_rtc_domain
        default_backend element_backend

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
        server mas 127.0.0.1:8181 send-proxy

      backend lk_jwt_backend
        http-request return status 204 hdr "Access-Control-Allow-Origin" "*" hdr "Access-Control-Allow-Methods" "GET, POST, OPTIONS" hdr "Access-Control-Allow-Headers" "Authorization, Content-Type, X-Requested-With" if { method OPTIONS }
        http-request replace-path ^/livekit/jwt(.*) \1
        http-request replace-path ^/livekit(.*) \1
        http-response set-header Access-Control-Allow-Origin "*"
        http-response set-header Access-Control-Allow-Methods "GET, POST, OPTIONS"
        http-response set-header Access-Control-Allow-Headers "Authorization, Content-Type, X-Requested-With"
        http-response set-header Access-Control-Expose-Headers "Content-Type, Authorization, Origin, X-Requested-With"
        server lk_jwt 127.0.0.1:8081

      backend lk_sfu_backend
        http-request replace-path ^/livekit/sfu(.*) \1
        timeout tunnel 3600s
        server lk_sfu 127.0.0.1:7880 check alpn http/1.1

      backend wellknown_backend
        http-request replace-path ^/\.well-known(.*) \1
        http-response set-header Access-Control-Allow-Origin "*"
        http-response set-header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        http-response set-header Access-Control-Allow-Headers "Content-Type, Origin, Authorization, X-Requested-With"
        http-response set-header Access-Control-Expose-Headers "Content-Type, Authorization, Origin"
        http-response set-header Content-Type "application/json"
        http-response set-header Cache-Control "no-store, no-cache, must-revalidate"
        server wellknown 127.0.0.1:8083

      backend tos_backend
        server tos 127.0.0.1:8085

      backend element_call_backend
        http-request redirect code 302 location https://${cfg.elementDomain} unless { query -m sub widgetId }
        http-response set-header X-Content-Type-Options "nosniff"
        http-response set-header X-XSS-Protection "1; mode=block"
        http-response set-header X-Robots-Tag "noindex, nofollow, noarchive, noimageindex"
        http-response set-header Content-Security-Policy "frame-ancestors https://${cfg.elementDomain}"
        server element_call 127.0.0.1:8084

      backend element_backend
        http-response set-header X-Frame-Options "SAMEORIGIN"
        http-response set-header X-Content-Type-Options "nosniff"
        http-response set-header Content-Security-Policy "frame-ancestors 'self'"
        http-response set-header X-XSS-Protection "1; mode=block"
        http-response set-header X-Robots-Tag "noindex, nofollow, noarchive, noimageindex"
        server element 127.0.0.1:8082

      frontend matrix_bridge
        bind 127.0.0.1:8090
        http-request set-header X-Forwarded-Proto https
        acl is_mas_compat_auth path_reg ^/_matrix/client/[^/]+/(login|logout|refresh)
        acl is_mas_compat      path_beg /complete-compat-sso
        acl is_mas_auth        path_beg /auth
        acl is_mas_oidc        path_beg /_mas
        use_backend mas_backend if is_mas_compat_auth or is_mas_compat or is_mas_auth or is_mas_oidc
        default_backend synapse_backend
    '';
  };
}
