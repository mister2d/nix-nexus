# Hermes: AI Agent Gateway

Hermes is a NixOS LXC host (`hermes`). It runs the
[hermes-agent](https://github.com/numtide/llm-agents.nix) gateway as a user-level
systemd service for the `groot` user. The gateway connects to Matrix. It exposes
an AI agent that uses a local LLM on Petunia.

---

## Architecture

```
petunia:8000 (llama.cpp)
        │
        └── hermes-gateway (groot@hermes, user systemd)
                │
                ├── Matrix platform adapter (@bottymouth:matrix.novuscotia.com)
                └── ~/.hermes/config.yaml  (runtime config, not HM-managed)
```

The gateway Python environment is assembled in `hosts/hermes/home.nix`. It reaches
the service through a systemd drop-in at
`~/.config/systemd/user/hermes-gateway.service.d/nix-deps.conf`.

---

## Matrix platform: authentication

### Components

| Component | Location | Notes |
|---|---|---|
| Bot account | `@bottymouth:matrix.novuscotia.com` | MAS/SSO homeserver, no password login |
| Access token | `~/.env` as `MATRIX_ACCESS_TOKEN` | Bound to a specific device ID. Both live in `secrets/hermes.yaml` |
| Device ID | `~/.env` as `MATRIX_DEVICE_ID` | Regenerated on every token rotation |
| E2EE crypto store | `~/.hermes/platforms/matrix/store/crypto.db` | OLM account, Megolm sessions |

The homeserver uses Matrix Authentication Service (MAS) with SSO-only login.
`@bottymouth` has no password. All access tokens must come from the MAS CLI on
the matrix host.

### Issuing a new access token

Run both commands on the **matrix host**. Use `systemd-run` to assume the
`matrix-authentication-service` identity:

```bash
# Step 1 — kill all existing sessions for bottymouth
# This deregisters the device and clears its one-time keys from the homeserver.
systemd-run \
  --uid=matrix-authentication-service \
  --gid=matrix-authentication-service \
  --property=SupplementaryGroups=matrix-secrets \
  --property=WorkingDirectory=/var/lib/matrix-authentication-service \
  --wait --collect --pipe \
  /nix/store/<mas-version>/bin/mas-cli \
  --config /run/vault-secrets/mas-config.yaml manage kill-sessions \
  bottymouth

# Step 2 — issue a new compat token for the same device ID
# Output goes to the journal if --pipe is omitted; include --pipe to see it inline.
systemd-run \
  --uid=matrix-authentication-service \
  --gid=matrix-authentication-service \
  --property=SupplementaryGroups=matrix-secrets \
  --property=WorkingDirectory=/var/lib/matrix-authentication-service \
  --wait --collect --pipe \
  /nix/store/<mas-version>/bin/mas-cli \
  --config /run/vault-secrets/mas-config.yaml manage issue-compatibility-token \
  bottymouth
```

**Do not pass a device ID.** If you omit it, MAS generates a fresh one. MAS
prints the new ID alongside the token. You need both values.

Reusing a device ID breaks E2EE. Matrix device keys are **immutable per device
ID**. Once uploaded, the homeserver never replaces its copy. Wiping the crypto
store creates a new OLM account. The server still advertises the old identity
keys. Senders then encrypt messages to keys the bot does not hold. The
symptom is the error `No one-time keys nor device keys got when trying to
share keys`. Repeated `Failed to decrypt megolm event` errors follow. This is
unrecoverable for that device ID.

Get the current MAS store path from the running unit. Do not hardcode it:

```bash
systemctl show matrix-authentication-service -p ExecStart --value \
  | grep -oE '/nix/store/[^ ]*/bin/mas-cli'
```

The config lives at `/run/vault-secrets/mas-config.yaml`. vault-agent renders
it. Its permissions are `0640 root:matrix-secrets`. The CLI must run under
that identity for this reason. Do not confuse this path with `/run/secrets`,
which sops-nix owns.

If the token output does not appear on the terminal, check the journal:

```bash
journalctl -t mas-cli --since "5 minutes ago"
```

### Completing a token rotation on hermes

After issuing a new token on the matrix host:

```bash
# 1. Update BOTH gateway/matrix-access-token and gateway/matrix-device-id
#    in secrets/hermes.yaml (sops secrets/hermes.yaml), then redeploy hermes.
#    The env files are rendered by sops-nix — do not edit ~/.hermes/.env.

# 2. Wipe the crypto store — the old OLM account is now orphaned
rm ~/.hermes/platforms/matrix/store/crypto.db{,-shm,-wal}

# 3. Restart the gateway
systemctl --user restart hermes-gateway
```

### Why the crypto store must be wiped with the token

The homeserver, the access token, and the local crypto store form a matched
triple:

- The **access token** is bound to a specific **device ID** on the homeserver.
- The **crypto store** holds the OLM account for that device. This account
  includes its one-time keys (OTKs).
- When you deregister a device with `kill-sessions`, the homeserver discards
  all its OTKs.
- If you keep the crypto store while you replace the device, the new OLM
  account tries to upload OTKs. It starts from index `AAAAAQ`. The homeserver
  already has those key indexes from the old account. This produces
  `MUnknown: One time key already exists` errors. These errors block the E2EE
  session setup.

Always wipe the crypto store when you deregister the device on the homeserver.
The reverse rule also applies. Do not deregister the device without replacing
the token. Otherwise the gateway connects with an invalid token.

---

## Environment variables

Home Manager sets these in the systemd drop-in
(`~/.config/systemd/user/hermes-gateway.service.d/nix-deps.conf`). Home
Manager generates this file from `hosts/hermes/home.nix`. The drop-in also
reads `~/.env` through `EnvironmentFile`. `Environment=` lines in the drop-in
take priority over `.env` values.

| Variable | Value | Effect |
|---|---|---|
| `MATRIX_E2EE_MODE` | `optional` | Enables E2EE when supported. Uses plain text otherwise |
| `MATRIX_REQUIRE_MENTION` | `false` | Bot responds without @mention in rooms |
| `MATRIX_ALLOW_ALL_USERS` | `true` | The bot authorizes all room members (no per-user allowlist) |
| `MATRIX_AUTO_THREAD` | _(unset, defaults `true`)_ | Bot replies create a new Matrix thread per message |
| `MATRIX_ACCESS_TOKEN` | _(in `~/.env`)_ | Access token bound to `MATRIX_DEVICE_ID` |
| `MATRIX_DEVICE_ID` | _(in `~/.env`)_ | Currently `753fyy1CAT` |

### Threaded replies

hermes-agent 2026.6.x introduced `MATRIX_AUTO_THREAD` with a default of
`true`. Earlier versions sent flat room messages. To restore flat replies,
add this line to the drop-in:

```
Environment="MATRIX_AUTO_THREAD=false"
```

This requires a Home Manager rebuild and service restart.

---

## Runtime config

`/home/groot/.hermes/config.yaml` is the default hermes profile config. Home
Manager does **not** manage this file. hermes-agent writes to it at runtime,
for example to `onboarding.seen` and `_config_version`. Do not manage it with
`home.file`. That setting would make the file read only and stop hermes-agent
writes.

Note this key setting:

```yaml
matrix:
  require_mention: false    # must stay false; env var alone is not sufficient
                            # because config.extra takes priority over env vars
                            # in _parse_require_mention()
```

If this value reverts to `true`, for example after a config schema migration,
the bot goes silent in unmonitored rooms. Fix:

```bash
sed -i 's/^  require_mention: true$/  require_mention: false/' \
  /home/groot/.hermes/config.yaml
systemctl --user restart hermes-gateway
```

---

## context-mode plugin

`hosts/hermes/llm-agents-overlay.nix` and `hosts/hermes/groot-hm.nix` package
`context-mode-hermes` (a hermes-agent plugin) and `context-mode` (its
companion Node CLI). Nix only puts the plugin on `PYTHONPATH` and the CLI on
`PATH`. Activation needs a manual edit to `/home/groot/.hermes/config.yaml`.
This file stays hand-owned for the same reason given in "Runtime config"
above.

Add both of these entries to `config.yaml`:

```yaml
plugins:
  enabled:
    - context-mode        # REQUIRED - entry-point plugins are opt-in
mcp_servers:
  context-mode:
    command: context-mode
```

The `plugins.enabled` entry is required. Upstream's README does not mention
this requirement. `hermes_cli/plugins.py` treats an absent `plugins.enabled`
key as nothing enabled. The `plugins.disabled` deny list always wins over
`plugins.enabled` when both list the same plugin.

Then restart both gateway units so the new PYTHONPATH and config take effect:

```bash
systemctl --user restart hermes-gateway hermes-gateway-coding-local
```

### Runtime state

The plugin creates state that Nix does not declare or manage:

- `CONTEXT_MODE_DIR` (default `~/.local/share/hermes-context-mode`) is a
  SQLite FTS5 knowledge base.
- Transient marker files under `$TMPDIR`.

---

## Nix store paths

| Component | Path |
|---|---|
| hermes-agent package | `pkgs.llm-agents.hermes-agent` (via `hermes-mcp-overlay`) |
| Python environment | Assembled in `hosts/hermes/home.nix` |
| NixOS assembly | `modules/flake/nixos-hermes.nix` |
| Host config | `hosts/hermes/default.nix` |
| HM wiring | `hosts/hermes/groot-hm.nix` |
| HM module | `hosts/hermes/home.nix` (key: `hermes-home`) |
