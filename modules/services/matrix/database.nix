# Merged into: flake.modules.nixos.services-matrix
# Configures: the PostgreSQL databases for Synapse and Matrix Authentication Service.
# Imported by: hosts/avina/default.nix (avina-default).
_: {
  flake.modules.nixos.services-matrix =
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

        # Force 'C' collation for Synapse and ensure all roles/databases exist.
        initialScript = pkgs.writeText "matrix-db-init.sql" ''
          -- Ensure roles exist
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

          -- Create Synapse DB (Strict 'C' Collation)
          SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'matrix-synapse' AND pid <> pg_backend_pid();
          DROP DATABASE IF EXISTS "matrix-synapse";
          CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse" TEMPLATE = template0 LC_COLLATE = 'C' LC_CTYPE = 'C';

          -- Create MAS DB
          SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'matrix-authentication-service' AND pid <> pg_backend_pid();
          DROP DATABASE IF EXISTS "matrix-authentication-service";
          CREATE DATABASE "matrix-authentication-service" WITH OWNER "matrix-authentication-service";
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
    };
}
