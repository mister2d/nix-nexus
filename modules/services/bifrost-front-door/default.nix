# Unified HTTPS edge for petunia (one HAProxy on :443, one certificate).
# Registry key: flake.modules.nixos.services-bifrost-front-door
# Host routes: inference (bifrost), radiance, pictures (qwen-image-mcp), pi
# (pi-durable web bridge and webhooks). petunia.home.lan itself serves only
# /stats and /metrics; every other path answers 421. Backends bind loopback.
# Imports the module from the nix-bifrost flake input and points the Vault
# AppRole credentials at the core-credstore directory. The files are sealed by
# hand with systemd-creds (--name=role_id / --name=secret_id, TPM2 PCR 0).
# See docs/petunia.md.
{ inputs, ... }:
{
  flake.modules.nixos.services-bifrost-front-door =
    { config, ... }:
    let
      credsDir = config.nix-nexus.secrets.credstore.dir;
    in
    {
      imports = [ inputs.nix-bifrost.nixosModules.bifrost-front-door ];

      services.bifrost-front-door = {
        enable = true;
        openFirewall = true;
        listen.port = 443;
        extraNames = [
          "inference.home.lan"
          "pictures.home.lan"
          "pi.home.lan"
          "radiance.home.lan"
        ];
        defaultRoutes.enable = false;
        stats.enable = true;
        prometheus.enable = true;
        routes = {
          inference = {
            host = "inference.home.lan";
            upstream.port = 8080;
            healthCheck.path = "/health";
            serverTimeoutSeconds = 900;
          };
          # Direct to the radiance slots, never to llama-swap: a request here
          # cannot load a model, so it cannot swap one out (Bifrost is the
          # only client that makes llama-swap load). llama-swap runs the LLM on
          # 8000, or on 8002 with the image model on 8003 (GPU pair groups).
          # `first` sends traffic to the live LLM slot. radiance-slots.nix sets
          # a slot that llama-swap has not loaded to maint, so the stats show
          # it as maint and keep DOWN for a loaded slot that fails.
          radiance = {
            host = "radiance.home.lan";
            upstream.servers = [
              {
                name = "llm-8000";
                port = 8000;
              }
              {
                name = "llm-8002";
                port = 8002;
              }
              {
                name = "img-8003";
                port = 8003;
                pinOnly = true;
              }
            ];
            balance = "first";
            # Per-instance dashboard and metrics: /slot/<port>/..., 503 when idle.
            slotPrefix = "/slot";
            healthCheck.path = "/health";
            serverTimeoutSeconds = 900;
          };
          pictures = {
            host = "pictures.home.lan";
            upstream.port = 8004;
            healthCheck.path = "/healthz";
            serverTimeoutSeconds = 120;
            denyPaths = [ "/mcp" ];
          };
          pi = {
            host = "pi.home.lan";
            upstream.port = 8787;
            healthCheck.path = "/healthz";
            serverTimeoutSeconds = 3600;
          };
          # Signed webhooks go to the pi-durable trigger service "ops".
          pi-hooks = {
            host = "pi.home.lan";
            pathPrefix = "/hook";
            stripPrefix = false;
            upstream.port = 9811;
            healthCheck.path = "/healthz";
            serverTimeoutSeconds = 60;
          };
        };
        tls.vault.credentials = {
          roleIdEncryptedFile = "${credsDir}/bifrost-front-door.role_id";
          secretIdEncryptedFile = "${credsDir}/bifrost-front-door.secret_id";
        };
      };
    };
}
