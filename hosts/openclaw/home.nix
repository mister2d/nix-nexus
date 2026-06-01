_: {
  flake.modules.homeManager.openclaw-home = _: {
    # Source Vault-rendered secrets and inject the pre-fetched Matrix crypto
    # native binary for interactive shells. Both the openclaw CLI (auth) and
    # the crypto bootstrap (NODE_PATH) require these to be set.
    programs.bash.initExtra = ''
      # Inject the pre-fetched Matrix crypto binary so openclaw does not try
      # to download it into the read-only Nix store.
      export NODE_PATH=/run/openclaw/node_modules

      # Load Vault-rendered secrets so the openclaw CLI can authenticate
      # with the gateway (e.g. for pairing Matrix users).
      if [ -f /run/secrets/openclaw.env ]; then
        set -a
        # shellcheck source=/dev/null
        source /run/secrets/openclaw.env
        set +a
      fi
    '';

    # Manage the openclaw-gateway systemd user service override declaratively.
    # openclaw installs its own unit; this drop-in:
    #   1. Blocks startup until /run/secrets/openclaw.env is rendered by vault-agent-init
    #   2. Loads the env file so openclaw.json SecretRefs (source: "env") resolve correctly
    #   3. Injects NODE_PATH for the missing Matrix crypto native binary (NixOS compat fix)
    xdg.configFile."systemd/user/openclaw-gateway.service.d/overrides.conf".text = ''
      [Service]
      # Expose the writable crypto module path to Node.js.
      Environment="NODE_PATH=/run/openclaw/node_modules"

      # Extend start timeout to outlast vault-agent-init rendering time.
      # The base unit has TimeoutStartSec=30 which would kill the poll loop.
      TimeoutStartSec=120

      # Block until vault-agent-init has rendered the env file.
      # ConditionPathExists is intentionally absent: it causes a silent skip on
      # boot (not a failure), so Restart=always never fires. The poll loop here
      # is the correct mechanism for waiting across the race with vault-agent-init.
      ExecStartPre=/run/current-system/sw/bin/sh -c 'until [ -f /run/secrets/openclaw.env ]; do sleep 1; done'

      # Load Vault-rendered secrets; referenced in openclaw.json via source: "env".
      EnvironmentFile=/run/secrets/openclaw.env

      # Ensure mcp-nixos is in the PATH
      Environment="PATH=/run/wrappers/bin:/home/groot/.nix-profile/bin:/nix/profile/bin:/home/groot/.local/state/nix/profile/bin:/etc/profiles/per-user/groot/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
    '';
  };
}
