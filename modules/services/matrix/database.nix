{
  pkgs,
  ...
}:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;

    # Performance Tuning (VM Optimization)
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

    # Database Provisioning:
    # Synchronizes database identities and enforces Synapse-specific collation.
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

    # Synapse Invariant:
    # Enforces LC_COLLATE = 'C' to ensure database performance and correctness.
    initialScript = pkgs.writeText "matrix-db-init.sql" ''
      CREATE DATABASE "matrix-synapse" LC_COLLATE = 'C' OWNER "matrix-synapse";
      CREATE DATABASE "matrix-authentication-service" OWNER "matrix-authentication-service";
    '';
  };
}
