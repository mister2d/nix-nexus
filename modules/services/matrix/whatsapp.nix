{ matrixDomain, ... }:
{
  # mautrix-whatsapp carries a libolm dependency in nixpkgs. libolm is deprecated
  # and has known side-channel CVEs (CVE-2024-45191/45192/45193), but upstream does
  # not consider them practically exploitable over the network. Permitted explicitly
  # here; revisit when nixpkgs migrates the package to vodozemac.
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];

  services.mautrix-whatsapp = {
    enable = true;

    # Secrets injected at runtime — never in the Nix store.
    # MAUTRIX_WHATSAPP_ENCRYPTION_PICKLE_KEY       → encryption.pickle_key
    # MAUTRIX_WHATSAPP_BRIDGE_LOGIN_SHARED_SECRET  → double_puppet.secrets."<domain>"
    #   (NixOS module injects this automatically using homeserver.domain as the key)
    environmentFile = "/run/secrets/whatsapp-env";

    settings = {
      homeserver = {
        address = "http://127.0.0.1:8008";
        domain = matrixDomain;
      };

      appservice = {
        # address: URL Synapse uses to reach the bridge (written into registration.yaml).
        address = "http://127.0.0.1:29318";
        # hostname: what the bridge binds to — localhost only, not exposed externally.
        hostname = "127.0.0.1";
        port = 29318;
        id = "whatsapp";
        bot = {
          username = "whatsappbot";
          displayname = "WhatsApp Bridge Bot";
        };
      };

      database = {
        type = "postgres";
        uri = "postgresql:///mautrix_whatsapp?host=/run/postgresql";
      };

      bridge = {
        # Private server: restrict to homeserver users only.
        permissions = {
          "@groot:${matrixDomain}" = "admin";
          "${matrixDomain}" = "user";
        };
        command_prefix = "!wa";
        # Relay disabled — invite-only homeserver, no anonymous relay bridging.
        relay.enabled = false;
      };

      encryption = {
        allow = true;
        default = true;
        require = true;
        # pickle_key must never change after first use — invalidates all bridge sessions.
        # Value injected from /run/secrets/whatsapp-env at runtime.
        pickle_key = "$MAUTRIX_WHATSAPP_ENCRYPTION_PICKLE_KEY";
      };

      # HTTP provisioning API disabled — bridge is managed via Matrix bot commands only.
      provisioning.shared_secret = "disable";

      network = {
        displayname_template = "{{or .BusinessName .PushName .Phone}} (WA)";
        history_sync.request_full_sync = true;
        identity_change_notices = true;
      };
    };
  };

  # Register the bridge with Synapse.
  # The NixOS mautrix-whatsapp module writes the registration YAML to this path
  # (via matrix-synapse-register-mautrix-whatsapp.service before Synapse starts).
  services.matrix-synapse.settings.app_service_config_files = [
    "/var/lib/mautrix-whatsapp/whatsapp-registration.yaml"
  ];
}
