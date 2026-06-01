_: {
  flake.modules.nixos.services-matrix-mas =
    { pkgs, ... }:
    let
      stateDir = "/var/lib/matrix-authentication-service";
      configFile = "/run/secrets/mas-config.yaml";
    in
    {
      users.users.matrix-authentication-service = {
        isSystemUser = true;
        group = "matrix-authentication-service";
        home = stateDir;
        createHome = true;
        description = "Matrix Authentication Service daemon user";
      };
      users.groups.matrix-authentication-service = { };

      systemd.services.matrix-authentication-service = {
        description = "Matrix Authentication Service (MAS) — MSC3861 native OIDC provider";
        documentation = [ "https://matrix-org.github.io/matrix-authentication-service/" ];
        after = [
          "network.target"
          "postgresql.service"
        ];
        requires = [ "postgresql.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          User = "matrix-authentication-service";
          Group = "matrix-authentication-service";
          StateDirectory = "matrix-authentication-service";
          WorkingDirectory = stateDir;

          # Process Lifecycle:
          # Ensure database schema is up-to-date before the application server starts.
          ExecStartPre =
            "${pkgs.matrix-authentication-service}/bin/mas-cli " + "database migrate --config ${configFile}";
          ExecStart = "${pkgs.matrix-authentication-service}/bin/mas-cli " + "server --config ${configFile}";

          Restart = "on-failure";
          RestartSec = "5s";

          # Security & Sandboxing:
          # Strict process isolation following the nix-nexus core security patterns.
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ stateDir ];
          ReadOnlyPaths = [ configFile ];
          CapabilityBoundingSet = [ ];
          AmbientCapabilities = [ ];
        };
      };
    };
}
