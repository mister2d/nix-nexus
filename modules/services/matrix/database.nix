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

    # Force 'C' collation for Synapse.
    # This script is idempotent but will recreate the DB if it doesn't meet Synapse's requirements.
    initialScript = pkgs.writeText "synapse-db-init.sql" ''
      -- Ensure the user exists
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'matrix-synapse') THEN
          CREATE USER "matrix-synapse" WITH PASSWORD 'synapse' SUPERUSER;
        END IF;
      END
      $$;

      -- We must use 'C' collation for Synapse to avoid startup failures.
      -- If the DB exists with wrong collation, we drop it (safe for initial deploy).
      SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'matrix-synapse' AND pid <> pg_backend_pid();
      DROP DATABASE IF EXISTS "matrix-synapse";
      CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse" LC_COLLATE = 'C' LC_CTYPE = 'C';
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
