{
  pkgs,
  lib,
  ...
}:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    settings = {
      listen_addresses = lib.mkForce ""; # Process communication via Unix socket only

      # Synapse Performance Tuning:
      # These parameters follow official Synapse guidance for a 12GB RAM instance
      # and are optimized for SSD-backed ZFS storage.
      max_connections = 100;
      shared_buffers = "3GB";
      effective_cache_size = "8GB";
      maintenance_work_mem = "512MB";
      checkpoint_completion_target = 0.9;
      wal_buffers = "16MB";
      default_statistics_target = 100;
      random_page_cost = 1.1;
      effective_io_concurrency = 200;
      work_mem = "16MB";
      min_wal_size = "1GB";
      max_wal_size = "4GB";
    };
    ensureUsers = [
      {
        name = "matrix-synapse";
        ensureDBOwnership = true;
      }
      {
        name = "matrix-authentication-service";
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [
      "matrix-synapse"
      "matrix-authentication-service"
    ];

    # Database Provisioning:
    # Idempotent database creation logic. Synapse requires LC_COLLATE = 'C'
    # which must be specified at creation time.
    initialScript = pkgs.writeText "synapse-pg-init.sql" ''
      SELECT 'CREATE DATABASE "matrix-synapse"
        ENCODING 'UTF8'
        LC_COLLATE = 'C'
        LC_CTYPE = 'C'
        TEMPLATE template0'
      WHERE NOT EXISTS (
        SELECT FROM pg_database WHERE datname = 'matrix-synapse'
      )\gexec
      GRANT ALL ON DATABASE "matrix-synapse" TO "matrix-synapse";
    '';
  };
}
