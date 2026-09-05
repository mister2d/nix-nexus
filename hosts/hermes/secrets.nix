# Host: hermes (NixOS x86_64 Proxmox LXC server).
# Registry key: flake.modules.nixos.hermes-default
# Contributes: sops secrets and env templates for the hermes-agent gateway and coding-local profile.
_: {
  flake.modules.nixos.hermes-default =
    { config, ... }:
    let
      home = config.users.users.groot.home;

      # hermes-agent loads $HERMES_HOME/.env itself, with override=True, so
      # values it finds there outrank anything systemd injects. Rendering to
      # the paths it already reads is the only way to supply secrets to it.
      # HERMES_HOME is profile-aware: the base gateway reads ~/.hermes, the
      # coding-local profile reads ~/.hermes/profiles/coding-local.
      gatewayEnv = "${home}/.hermes/.env";
      codingLocalEnv = "${home}/.hermes/profiles/coding-local/.env";

      inherit (config.sops) placeholder;
    in
    {
      nix-nexus.secrets.sops.hostFile = ../../secrets/hermes.yaml;

      # Only the sensitive values are encrypted. Everything else stays visible
      # in the templates below so endpoints and toggles remain reviewable.
      sops.secrets = {
        "gateway/matrix-access-token" = { };
        "gateway/matrix-home-room" = { };
        "gateway/matrix-device-id" = { };
        "gateway/crawl4ai-auth-token" = { };
        "gateway/google-maps-api-key" = { };
        "gateway/langfuse-public-key" = { };
        "gateway/langfuse-secret-key" = { };

        "coding-local/api-server-key" = { };
        "coding-local/github-pat" = { };
        "coding-local/langfuse-public-key" = { };
        "coding-local/langfuse-secret-key" = { };
      };

      sops.templates = {
        "hermes-gateway-env" = {
          path = gatewayEnv;
          owner = "groot";
          mode = "0400";
          content = ''
            ## Matrix
            MATRIX_HOMESERVER=https://matrix.novuscotia.com
            MATRIX_ACCESS_TOKEN=${placeholder."gateway/matrix-access-token"}
            MATRIX_USER_ID=@bottymouth:matrix.novuscotia.com
            MATRIX_ENCRYPTION=true
            MATRIX_ALLOWED_USERS=@dana:matrix.novuscotia.com
            MATRIX_HOME_ROOM=${placeholder."gateway/matrix-home-room"}
            MATRIX_HOME_ROOM_THREAD_ID=
            MATRIX_DEVICE_ID=${placeholder."gateway/matrix-device-id"}
            MATRIX_AUTO_THREAD=true
            MATRIX_DM_AUTO_THREAD=true

            ## Hermes Memory Provider
            MEMVID_MCP_TRANSPORT=http
            MEMVID_MCP_URL=http://dualie.home.lan:20002/mcp

            ## Tika endpoint
            TIKA_BASE_URL=https://tika.service.internal.novuscotia.com

            ## Crawl4ai
            CRAWL4AI_URL="https://crawl4ai.service.internal.novuscotia.com"
            CRAWL4AI_AUTH_TOKEN=${placeholder."gateway/crawl4ai-auth-token"}

            ## Google Maps
            GOOGLE_MAPS_API_KEY=${placeholder."gateway/google-maps-api-key"}

            ## LangFuse traces
            HERMES_LANGFUSE_PUBLIC_KEY=${placeholder."gateway/langfuse-public-key"}
            HERMES_LANGFUSE_SECRET_KEY=${placeholder."gateway/langfuse-secret-key"}
            HERMES_LANGFUSE_BASE_URL=https://langfuse.service.internal.novuscotia.com

            NOMAD_ADDR=https://nomad.service.consul:4646
          '';
        };

        "hermes-coding-local-env" = {
          path = codingLocalEnv;
          owner = "groot";
          mode = "0400";
          content = ''
            ## API Server
            API_SERVER_ENABLED=true
            API_SERVER_PORT=8643
            API_SERVER_HOST=0.0.0.0
            API_SERVER_KEY=${placeholder."coding-local/api-server-key"}
            API_SERVER_MODEL_NAME=hermes-agent

            ## Hermes Memory Provider
            MEMVID_MCP_TRANSPORT=http
            MEMVID_MCP_URL=http://dualie.home.lan:20003/mcp

            ## Tika endpoint
            TIKA_BASE_URL=https://tika.service.internal.novuscotia.com

            GITHUB_PERSONAL_ACCESS_TOKEN=${placeholder."coding-local/github-pat"}

            ## Crawl4ai
            CRAWL4AI_URL="https://crawl4ai.service.internal.novuscotia.com"
            CRAWL4AI_AUTH_TOKEN="dummy"

            ## LangFuse traces
            HERMES_LANGFUSE_PUBLIC_KEY=${placeholder."coding-local/langfuse-public-key"}
            HERMES_LANGFUSE_SECRET_KEY=${placeholder."coding-local/langfuse-secret-key"}
            HERMES_LANGFUSE_BASE_URL=https://langfuse.service.internal.novuscotia.com
          '';
        };
      };
    };
}
