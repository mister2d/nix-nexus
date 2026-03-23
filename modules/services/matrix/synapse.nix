{
  matrixDomain,
  coturnRealm,
  federatedDomains ? [ ],
  ...
}:
{
  services.matrix-synapse = {
    enable = true;
    withJemalloc = true;

    settings = {
      server_name = matrixDomain;
      public_baseurl = "https://${matrixDomain}";

      # Authentication Policy:
      # Native OIDC delegation to the Matrix Authentication Service (MAS).
      # This provides a unified identity layer for the communication stack.
      matrix_authentication_service = {
        enabled = true;
        issuer = "https://auth.${matrixDomain}";
        client_id = "synapse";
      };

      # Feature Set:
      # MatrixRTC and associated modern specifications are advertised to clients.
      experimental_features = { };

      password_config.enabled = false;

      # Media Connectivity (NAT Traversal):
      # Integrated STUN/TURN support via the fleet Coturn relay.
      turn_uris = [
        "turn:${coturnRealm}:3478?transport=udp"
        "turn:${coturnRealm}:3478?transport=tcp"
        "turns:${coturnRealm}:5349?transport=tcp"
      ];
      turn_user_lifetime = 86400000;

      # Federated Posture:
      # Restrict federation to a specific set of trusted domains (Private Federation).
      # Inclusion of matrixDomain is mandatory for server health.
      federation_domain_whitelist = [ matrixDomain ] ++ federatedDomains;

      # Email Notifications (Mailgun):
      # Sensitive values (smtp_pass) are provisioned via synapse-email.yaml.
      email = {
        enable_notifs = true;
        smtp_host = "smtp.mailgun.org";
        smtp_port = 587;
        smtp_user = "postmaster@mg.novuscotia.com";
        require_transport_security = true;
        notif_from = "Matrix <noreply@novuscotia.com>";
      };

      # Proxy Trust Model:
      # Trust HAProxy on the local loopback for secure header propagation.
      trusted_proxies = [ "127.0.0.1" ];

      database = {
        name = "psycopg2";
        args = {
          user = "matrix-synapse";
          database = "matrix-synapse";
          host = "/run/postgresql";
          cp_min = 5;
          cp_max = 10;
          # Database Resilience:
          keepalives_idle = 10;
          keepalives_interval = 10;
          keepalives_count = 3;
        };
      };

      # Ingress Listeners:
      # Synapse listens locally; all public traffic is routed through HAProxy.
      listeners = [
        {
          port = 8008;
          tls = false;
          type = "http";
          x_forwarded = true;
          resources = [
            {
              names = [
                "client"
                "federation"
              ];
              compress = false;
            }
          ];
        }
      ];
    };

    extraConfigFiles = [
      "/run/secrets/synapse-secrets.yaml"
      "/run/secrets/synapse-email.yaml"
    ];
  };

  # Service ordering
  systemd.services.matrix-synapse = {
    after = [
      "postgresql.service"
      "matrix-authentication-service.service"
    ];
    requires = [
      "postgresql.service"
      "matrix-authentication-service.service"
    ];
  };
}
