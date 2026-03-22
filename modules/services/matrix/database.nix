{
  pkgs,
  lib,
  ...
}:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    settings.listen_addresses = lib.mkForce ""; # Unix socket only
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
