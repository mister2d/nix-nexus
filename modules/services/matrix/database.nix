{ pkgs, ... }:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;

    # Performance Tuning (VM Optimization for 12GB RAM)
    settings = {
      max_connections = 100;
      shared_buffers = "1GB";
      effective_cache_size = "3GB";
      maintenance_work_mem = "256MB";
      checkpoint_completion_target = 0.9;
      wal_buffers = "16MB";
      default_statistics_target = 100;
      random_page_cost = 1.1;
      effective_io_concurrency = 200;
      work_mem = "10MB";
      min_wal_size = "1GB";
      max_wal_size = "4GB";
    };

    # Enforce 'C' locale for the entire cluster if initialized fresh.
    initdbArgs = [
      "--locale=C"
      "--encoding=UTF8"
    ];

    # Force 'C' collation for Synapse and ensure roles exist.
    initialScript = pkgs.writeText "synapse-db-init.sql" ''
      -- Ensure roles exist before they are used
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'matrix-synapse') THEN
          CREATE USER "matrix-synapse" WITH PASSWORD 'synapse' SUPERUSER;
        END IF;
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'matrix-authentication-service') THEN
          CREATE USER "matrix-authentication-service";
        END IF;
      END
      $$;

      -- Use template0 to allow 'C' collation when cluster default is different (e.g. en_US.UTF-8).
      -- We drop the existing DB to ensure a clean state for the initial deployment.
      SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'matrix-synapse' AND pid <> pg_backend_pid();
      DROP DATABASE IF EXISTS "matrix-synapse";
      CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse" TEMPLATE = template0 LC_COLLATE = 'C' LC_CTYPE = 'C';
    '';

    ensureDatabases = [
      "matrix-synapse"
      "matrix-authentication-service"
    ];
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
  };
}
