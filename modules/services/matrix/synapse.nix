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

      # Suppression Policy:
      # Silences the 'trusted_key_servers' warning for matrix.org.
      suppress_key_server_warning = true;

      # Authentication Policy:
      # All OIDC/MAS settings (enabled, issuer, client_id, secret) are rendered
      # as a single unit in synapse-secrets.yaml to ensure deep-merge success.

      experimental_features = { };

      password_config.enabled = false;

      # Media Connectivity (NAT Traversal):
      turn_uris = [
        "turn:${coturnRealm}:3478?transport=udp"
        "turn:${coturnRealm}:3478?transport=tcp"
        "turns:${coturnRealm}:5349?transport=tcp"
      ];
      turn_user_lifetime = 86400000;

      # Federated Posture:
      federation_domain_whitelist = [ matrixDomain ] ++ federatedDomains;

      # Email Notifications:
      # All settings consolidated in synapse-email.yaml.

      # Proxy Trust Model:
      trusted_proxies = [ "127.0.0.1" ];

      database = {
        name = "psycopg2";
        args = {
          user = "matrix-synapse";
          database = "matrix-synapse";
          host = "/run/postgresql";
          cp_min = 5;
          cp_max = 10;
          keepalives_idle = 10;
          keepalives_interval = 10;
          keepalives_count = 3;
        };
      };

      # Ingress Listeners:
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
  };
}
