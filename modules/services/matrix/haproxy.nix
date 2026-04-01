{
  pkgs,
  lib,
  matrixDomain,
  masDomain,
  rtcDomain,
  elementDomain,
  ...
}:
let
  adminIPs = [
    "127.0.0.1"
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
  ];

  # Terms of Service:
  # Served at https://<matrixDomain>/tos and referenced by MAS branding.tos_uri.
  # This is a private, invite-only homeserver — no public registration.
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
      <p>This Matrix homeserver is a private, invite-only communication service. Access is
      restricted to authorised individuals. There is no public registration; all accounts
      are provisioned by the administrator.</p>

      <h2>2. Acceptable Use</h2>
      <p>You agree to use this service only for lawful, personal communication. The following
      are prohibited:</p>
      <ul>
        <li>Sharing, distributing, or storing illegal content of any kind.</li>
        <li>Harassing, threatening, or abusing other users.</li>
        <li>Attempting to gain unauthorised access to server infrastructure or other accounts.</li>
        <li>Using automated tools to send bulk messages or spam.</li>
        <li>Any activity that violates applicable law.</li>
      </ul>

      <h2>3. Privacy</h2>
      <p>Messages and files sent through this service are stored on the server. The
      administrator may access server logs and metadata for operational and security
      purposes. Do not transmit information you require to remain confidential using
      unencrypted Matrix rooms.</p>

      <h2>4. Account Termination</h2>
      <p>The administrator reserves the right to suspend or permanently remove access for
      any user who violates these terms, or for any other operational reason, without
      prior notice.</p>

      <h2>5. Availability</h2>
      <p>This service is provided on a best-effort basis with no uptime guarantees. The
      administrator accepts no liability for data loss, service interruptions, or any
      damages arising from use of the service.</p>

      <h2>6. Changes</h2>
      <p>These terms may be updated at any time. Continued use of the service after
      changes are posted constitutes acceptance of the revised terms.</p>

      <h2>7. Contact</h2>
      <p>Questions regarding these terms should be directed to the server administrator.</p>
    </body>
    </html>
  '';

  wellKnownConfig = pkgs.symlinkJoin {
    name = "matrix-well-known";
    paths = [
      (pkgs.writeTextDir "matrix/client" (
        builtins.toJSON {
          "m.homeserver" = {
            base_url = "https://${matrixDomain}";
          };
          # MSC3861 / MSC2965: advertise MAS as the OIDC provider.
          # m.authentication is the stable key (MSC3861); org.matrix.msc2965.authentication
          # is the legacy draft key retained for older clients. Both are needed: Element Web
          # uses the draft key in some versions; Element Call uses the stable key for
          # native OIDC discovery (MSC3861).
          "m.authentication" = {
            issuer = "https://${masDomain}/";
            account = "https://${masDomain}/account";
          };
          "org.matrix.msc2965.authentication" = {
            issuer = "https://${masDomain}/";
            account = "https://${masDomain}/account";
          };
          "org.matrix.msc3575.proxy" = {
            url = "https://${matrixDomain}";
          };
          "org.matrix.msc4143.rtc_foci" = [
            {
              type = "livekit";
              livekit_service_url = "https://${rtcDomain}/livekit/jwt";
              livekit_alias = matrixDomain;
            }
          ];
          # Element Desktop / Newer Element Web (some versions)
          "org.matrix.msc4143.rtc_web_v1" = {
            livekit = {
              preferred_url = "https://${rtcDomain}/livekit/sfu";
            };
          };
          # Element X / MSC4140
          "org.matrix.msc4140.rtc_focus" = {
            type = "livekit";
            livekit_service_url = "https://${rtcDomain}/livekit/jwt";
            livekit_alias = matrixDomain;
          };
          "org.matrix.msc4140.rtc_v1" = {
            livekit = {
              preferred_url = "https://${rtcDomain}/livekit/sfu";
            };
          };
          # Unified / Spec Keys
          "matrix_rtc" = {
            "urn:matrix:org.matrix.msc3861:livekit" = {
              preferred_url = "https://${rtcDomain}/livekit/sfu";
            };
          };
          "org.matrix.msc3861.matrix_rtc" = {
            "urn:matrix:org.matrix.msc3861:livekit" = {
              preferred_url = "https://${rtcDomain}/livekit/sfu";
            };
          };
        }
      ))
      # Federation server discovery: tells remote servers to connect on port 443
      # instead of the default 8448. Without this, lk-jwt-service (and any other
      # federation client) falls back to :8448 which is not exposed on avina.
      (pkgs.writeTextDir "matrix/server" (
        builtins.toJSON {
          "m.server" = "${matrixDomain}:443";
        }
      ))
    ];
  };
in
{
  # Terms of Service static server:
  # Serves /tos on port 8085; referenced by MAS branding.tos_uri.
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
        http-request set-header X-Forwarded-Proto https
        http-request set-header X-Cloudflare-Ray %[hdr(CF-Ray)] if { hdr(CF-Ray) -m found }
        http-request set-header X-Cloudflare-Country %[hdr(CF-IPCountry)] if { hdr(CF-IPCountry) -m found }

        # Component Routing Logic:
        # Dispatches traffic to the appropriate Matrix 2.0 component based on path/host.
        # MAS compat layer: matches any API version per official MAS reverse-proxy docs.
        acl is_mas_compat_auth  path_reg ^/_matrix/client/[^/]+/(login|logout|refresh)
        # MAS compat SSO callback: /complete-compat-sso/<token> lands on matrixDomain.
        acl is_mas_compat       path_beg /complete-compat-sso
        # MAS domain: all traffic on the auth subdomain routes to MAS.
        acl is_mas_domain       hdr(host) -i ${masDomain}
        acl is_mas_auth         path_beg /auth
        acl is_mas_oidc         path_beg /_mas
        acl is_lk_jwt           path_beg /livekit/jwt
        acl is_lk_sfu           path_beg /livekit/sfu or path_beg /twirp/
        acl is_lk_jwt_endpoint  path /livekit/jwt/sfu/get or path_beg /livekit/sfu/get
        acl is_matrix           path_beg /_matrix
        acl is_synapse          path_beg /_synapse
        acl is_wellknown        path_beg /.well-known
        acl is_tos              path_beg /tos
        acl is_rtc_domain       hdr(host) -i ${rtcDomain}

        # MSC4143 / MSC4140 / MatrixRTC transport discovery — served statically before backend routing.
        # Synapse requires auth on this endpoint but clients call it unauthenticated
        # as a capability check. The response is static and non-sensitive.
        # CORS required: Element Call (rtcDomain) and Element X (mobile) fetch this cross-origin.
        # Returning multiple variants (transports, foci, matrix_rtc) ensures
        # compatibility with JS SDK (msc4143), Rust SDK (msc4140), and Spec (matrix_rtc).
        acl is_rtc_discovery path /_matrix/client/unstable/org.matrix.msc4143/rtc/transports
        acl is_rtc_discovery path /_matrix/client/unstable/org.matrix.msc4140/rtc/transports
        acl is_rtc_discovery path /_matrix/client/v1/matrix_rtc/transports
        http-request return status 204 hdr "Access-Control-Allow-Origin" "*" hdr "Access-Control-Allow-Methods" "GET, POST, OPTIONS" hdr "Access-Control-Allow-Headers" "Authorization, Content-Type, Origin, X-Requested-With" hdr "Access-Control-Expose-Headers" "Content-Type, Authorization, Origin, X-Requested-With" if is_rtc_discovery { method OPTIONS }
        http-request return status 200 content-type "application/json" hdr "Access-Control-Allow-Origin" "*" hdr "Access-Control-Allow-Methods" "GET, POST, OPTIONS" hdr "Access-Control-Allow-Headers" "Authorization, Content-Type, Origin, X-Requested-With" hdr "Access-Control-Expose-Headers" "Content-Type, Authorization, Origin, X-Requested-With" string '{"transports":[{"type":"livekit","livekit_service_url":"https://${rtcDomain}/livekit/jwt","livekit_alias":"${matrixDomain}"}],"rtc_transports":[{"type":"livekit","livekit_service_url":"https://${rtcDomain}/livekit/jwt","livekit_alias":"${matrixDomain}"}],"foci":[{"type":"livekit","livekit_service_url":"https://${rtcDomain}/livekit/jwt","livekit_alias":"${matrixDomain}"}],"matrix_rtc":{"urn:matrix:org.matrix.msc3861:livekit":{"preferred_url":"https://${rtcDomain}/livekit/sfu"}},"org.matrix.msc3861.matrix_rtc":{"urn:matrix:org.matrix.msc3861:livekit":{"preferred_url":"https://${rtcDomain}/livekit/sfu"}}}' if is_rtc_discovery

        # CORS preflight for well-known discovery.
        http-request return status 204 hdr "Access-Control-Allow-Origin" "*" hdr "Access-Control-Allow-Methods" "GET, POST, PUT, DELETE, OPTIONS" hdr "Access-Control-Allow-Headers" "Content-Type, Origin, Authorization, X-Requested-With" hdr "Access-Control-Expose-Headers" "Content-Type, Authorization, Origin, X-Requested-With" if { path /.well-known/matrix/client } { method OPTIONS }

        use_backend mas_backend       if is_mas_domain or is_mas_compat_auth or is_mas_compat or is_mas_auth or is_mas_oidc
        use_backend element_call_backend if is_rtc_domain { path / } or is_rtc_domain { path_beg /assets } or is_rtc_domain { path /config.json } or is_rtc_domain { path /manifest.json }
        use_backend lk_jwt_backend    if is_lk_jwt_endpoint or is_lk_jwt
        use_backend lk_sfu_backend    if is_lk_sfu
        use_backend wellknown_backend if is_wellknown
        use_backend tos_backend       if is_tos
        use_backend synapse_backend   if is_matrix or is_synapse
        use_backend element_call_backend if is_rtc_domain
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
        server mas 127.0.0.1:8181 send-proxy

      backend lk_jwt_backend
        # CORS preflight: lk-jwt-service returns non-2xx for OPTIONS, which causes
        # browsers to block the actual JWT POST. Intercept here and return 204.
        http-request return status 204 hdr "Access-Control-Allow-Origin" "*" hdr "Access-Control-Allow-Methods" "POST, OPTIONS" hdr "Access-Control-Allow-Headers" "Authorization, Content-Type, X-Requested-With" if { method OPTIONS }
        # Path stripping:
        # Standard: /livekit/jwt/sfu/get -> /sfu/get
        # Rust SDK: /livekit/jwt/jwt/sfu/get -> /sfu/get
        # JS SDK fallback: /livekit/sfu/get -> /sfu/get
        http-request replace-path ^/livekit/jwt(.*) \1
        http-request replace-path ^/livekit(.*) \1
        # CORS headers on actual responses.
        http-response set-header Access-Control-Allow-Origin "*"
        http-response set-header Access-Control-Allow-Methods "POST, OPTIONS"
        http-response set-header Access-Control-Allow-Headers "Authorization, Content-Type, X-Requested-With"
        http-response set-header Access-Control-Expose-Headers "Content-Type, Authorization, Origin, X-Requested-With"
        server lk_jwt 127.0.0.1:8081

      backend lk_sfu_backend
        # Strip /livekit/sfu prefix — LiveKit server API is root-based.
        http-request replace-path ^/livekit/sfu(.*) \1
        # WebSocket Optimization:
        # matrix-rtc uses long-lived WebSockets for media signaling.
        # Default timeouts are too aggressive; set tunnel timeout to 1h.
        timeout tunnel 3600s
        server lk_sfu 127.0.0.1:7880 check alpn http/1.1

      backend wellknown_backend
        # Strip /.well-known prefix: darkhttpd serves from the Nix store where
        # the file lives at /matrix/client, not /.well-known/matrix/client.
        http-request replace-path ^/\.well-known(.*) \1
        # CORS required: Element Call (call.<domain>) fetches this cross-origin to
        # discover org.matrix.msc4143.rtc_foci. Without this header the browser
        # silently blocks the response and the client sees MISSING_MATRIX_RTC_TRANSPORT.
        http-response set-header Access-Control-Allow-Origin "*"
        http-response set-header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        http-response set-header Access-Control-Allow-Headers "Content-Type, Origin, Authorization, X-Requested-With"
        http-response set-header Access-Control-Expose-Headers "Content-Type, Authorization, Origin"
        server wellknown 127.0.0.1:8083

      backend tos_backend
        server tos 127.0.0.1:8085

      backend element_call_backend
        # Standalone redirect: direct browser visits (no widgetId param) are sent
        # to Element Web. Widget iframes from Element Web always include widgetId
        # in the query string and pass through unmodified.
        http-request redirect code 302 location https://${elementDomain} unless { query -m sub widgetId }
        # Security headers: allow framing from elementDomain — Element Call is 
        # embedded as a widget iframe.
        http-response set-header X-Content-Type-Options "nosniff"
        http-response set-header X-XSS-Protection "1; mode=block"
        http-response set-header X-Robots-Tag "noindex, nofollow, noarchive, noimageindex"
        http-response set-header Content-Security-Policy "frame-ancestors https://${elementDomain}"
        server element_call 127.0.0.1:8084

      backend element_backend
        # Security headers for Element Web. frame-ancestors 'self' prevents
        # clickjacking — Element Web is never embedded in third-party iframes.
        http-response set-header X-Frame-Options "SAMEORIGIN"
        http-response set-header X-Content-Type-Options "nosniff"
        http-response set-header Content-Security-Policy "frame-ancestors 'self'"
        http-response set-header X-XSS-Protection "1; mode=block"
        http-response set-header X-Robots-Tag "noindex, nofollow, noarchive, noimageindex"
        server element 127.0.0.1:8082

      # Internal bridge frontend — no TLS, loopback only.
      # Synapse with MAS enabled removes /_matrix/client/*/login entirely; bridges
      # need that endpoint for their startup capability check. Routing through here
      # sends auth paths to MAS's compat layer (which provides login flows) and all
      # other Matrix CS API calls to Synapse. Used by mautrix-whatsapp and any future
      # appservice bridges.
      frontend matrix_bridge
        bind 127.0.0.1:8090
        # Synapse checks X-Forwarded-Proto to determine if the original connection
        # was HTTPS. Without this, it logs a warning on every request from bridges.
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
