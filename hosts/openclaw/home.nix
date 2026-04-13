_: {
  # Manage the openclaw-gateway systemd user service override declaratively.
  # openclaw installs its own unit; this drop-in:
  #   1. Blocks startup until /run/secrets/openclaw.env is rendered by vault-agent-init
  #   2. Loads the env file so openclaw.json SecretRefs (source: "env") resolve correctly
  #   3. Injects NODE_PATH for the missing Matrix crypto native binary (NixOS compat fix)
  xdg.configFile."systemd/user/openclaw-gateway.service.d/overrides.conf".text = ''
    [Unit]
    ConditionPathExists=/run/secrets/openclaw.env

    [Service]
    # FIX: Inject the missing Matrix crypto native binary via NODE_PATH.
    Environment="NODE_PATH=/run/openclaw/node_modules"

    # Block until vault-agent-init has rendered the env file.
    ExecStartPre=/run/current-system/sw/bin/sh -c 'until [ -f /run/secrets/openclaw.env ]; do sleep 1; done'

    # Load Vault-rendered secrets; referenced in openclaw.json via source: "env".
    EnvironmentFile=/run/secrets/openclaw.env
  '';
}
