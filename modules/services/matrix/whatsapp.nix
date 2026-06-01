_: {
  flake.modules.nixos.services-matrix-whatsapp =
    {
      lib,
      pkgs,
      matrixDomain,
      ...
    }:
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
            # Internal HAProxy frontend on 8090: routes /_matrix/client/*/login to MAS
            # compat layer (Synapse+MAS disables this endpoint) and all else to Synapse.
            address = "http://127.0.0.1:8090";
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
            # Required for E2EE on next-gen auth (MSC3861/MAS) homeservers.
            # Uses device masquerading (MSC4190/MSC3202) instead of m.login.application_service,
            # which MAS removes. Changing this regenerates the appservice registration file.
            msc4190 = true;
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

      # Double-Puppet Namespace Fix:
      # Synapse enforces AS namespace checks when a bridge uses `as_token` masquerade.
      # The mautrix-whatsapp NixOS module does not expose a way to add extra namespaces
      # to the generated registration file, so we patch it declaratively here.
      #
      # This preStart runs BEFORE the module's ExecStartPre (which skips re-generating
      # the registration if the file already exists), so the namespace is present each
      # time the service starts.
      #
      # One-time migration note: after the first `nixos-rebuild switch` with this change,
      # run `systemctl restart matrix-synapse` once so Synapse reloads the updated
      # registration. Subsequent rebuilds are fully automatic.
      systemd.services.mautrix-whatsapp.preStart =
        let
          reg = "/var/lib/mautrix-whatsapp/whatsapp-registration.yaml";
        in
        ''
          if [ -f "${reg}" ] && ! ${lib.getExe pkgs.yq-go} \
              eval '.namespaces.users[] | select(.exclusive == false)' "${reg}" \
              | ${pkgs.gnugrep}/bin/grep -q .; then
            ${lib.getExe pkgs.yq-go} eval -i \
              '.namespaces.users += [{"regex": "^@.*:${matrixDomain}$", "exclusive": false}]' \
              "${reg}"
          fi
        '';
    };
}
