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
      listen_addresses = lib.mkForce ""; # Unix socket only
      # ── Synapse Tuning (12GB RAM Target) ──────────────────────────────────
      # Reference: https://matrix-org.github.io/synapse/latest/postgres.html
      max_connections = 100;
      shared_buffers = "3GB"; # 25% of RAM
      effective_cache_size = "8GB"; # 75% of RAM
      maintenance_work_mem = "512MB";
      checkpoint_completion_target = 0.9;
      wal_buffers = "16MB";
      default_statistics_target = 100;
      random_page_cost = 1.1; # Optimized for SSD (ZFS on NVMe/SSD)
      effective_io_concurrency = 200; # Optimized for SSD
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
    # matrix-synapse DB needs LC_COLLATE = "C" — ensureDatabases cannot set locale.
    # Use initialScript with idempotent CREATE DATABASE:
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
