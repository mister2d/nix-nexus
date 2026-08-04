# Hermes: AI Agent Gateway

Hermes is a NixOS LXC host (`hermes`) running the
[hermes-agent](https://github.com/numtide/llm-agents.nix) gateway as a user-level
systemd service for the `groot` user. It connects to Matrix and exposes an AI
agent backed by a local LLM on Petunia.

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

The gateway Python environment is assembled in `hosts/hermes/home.nix` and injected
via a systemd drop-in at
`~/.config/systemd/user/hermes-gateway.service.d/nix-deps.conf`.

---

## Matrix platform: authentication

### Components

| Component | Location | Notes |
|---|---|---|
| Bot account | `@bottymouth:matrix.novuscotia.com` | MAS/SSO homeserver; no password login |
| Access token | `~/.env` as `MATRIX_ACCESS_TOKEN` | Bound to a specific device ID; both live in `secrets/hermes.yaml` |
| Device ID | `~/.env` as `MATRIX_DEVICE_ID` | Regenerated on every token rotation |
| E2EE crypto store | `~/.hermes/platforms/matrix/store/crypto.db` | OLM account, Megolm sessions |

The homeserver uses Matrix Authentication Service (MAS) with SSO-only login.
There is no password for `@bottymouth`; all access tokens must be issued via
the MAS CLI on the matrix host.

### Issuing a new access token

Run both commands on the **matrix host** using `systemd-run` to assume the
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

**Do not pass a device ID.** Omitting it makes MAS generate a fresh one and
print it alongside the token; both values are needed.

Reusing a device ID is what breaks E2EE. Matrix device keys are **immutable
per device ID**: once uploaded, the homeserver's copy can never be replaced.
Wiping the crypto store creates a new OLM account, but the server keeps
advertising the old identity keys, so senders encrypt to keys the bot no
longer holds. The symptom is `No one-time keys nor device keys got when
trying to share keys` plus unending `Failed to decrypt megolm event`, and it
is unrecoverable for that device ID.

Get the current MAS store path from the running unit rather than hardcoding it:

```bash
systemctl show matrix-authentication-service -p ExecStart --value \
  | grep -oE '/nix/store/[^ ]*/bin/mas-cli'
```

The config lives at `/run/vault-secrets/mas-config.yaml`, rendered by
vault-agent. It is `0640 root:matrix-secrets`, which is why the CLI has to run
under that identity. Do not confuse it with `/run/secrets`, which sops-nix owns.

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

The homeserver, the access token, and the local crypto store form a matched triple:

- The **access token** is bound to a specific **device ID** on the homeserver.
- The **crypto store** holds the OLM account for that device, including its
  one-time keys (OTKs).
- When a device is deregistered (`kill-sessions`), the homeserver discards all
  its OTKs.
- If the crypto store is kept while the device is replaced, the new OLM account
  tries to upload OTKs starting from index `AAAAAQ` — but the homeserver already
  has those from the old account, causing `MUnknown: One time key already exists`
  errors and preventing E2EE session establishment.

Always wipe the crypto store whenever the device is deregistered on the homeserver.
The inverse is also true: do not deregister the device without replacing the token,
or the gateway will connect with an invalid token.

---

## Environment variables

These are set in the systemd drop-in
(`~/.config/systemd/user/hermes-gateway.service.d/nix-deps.conf`), which is
generated by Home Manager from `hosts/hermes/home.nix`. The drop-in also reads
`~/.env` via `EnvironmentFile`; `Environment=` lines in the drop-in take
precedence over `.env` values.

| Variable | Value | Effect |
|---|---|---|
| `MATRIX_E2EE_MODE` | `optional` | Enables E2EE when supported; falls back to plaintext |
| `MATRIX_REQUIRE_MENTION` | `false` | Bot responds without @mention in rooms |
| `MATRIX_ALLOW_ALL_USERS` | `true` | All room members are authorized (no per-user allowlist) |
| `MATRIX_AUTO_THREAD` | _(unset, defaults `true`)_ | Bot replies create a new Matrix thread per message |
| `MATRIX_ACCESS_TOKEN` | _(in `~/.env`)_ | Access token bound to `MATRIX_DEVICE_ID` |
| `MATRIX_DEVICE_ID` | _(in `~/.env`)_ | Currently `753fyy1CAT` |

### Threaded replies

`MATRIX_AUTO_THREAD` was introduced in hermes-agent 2026.6.x with a default of
`true`. Prior versions sent flat room messages. To restore flat replies, add to
the drop-in:

```
Environment="MATRIX_AUTO_THREAD=false"
```

This requires a Home Manager rebuild and service restart.

---

## Runtime config

`/home/groot/.hermes/config.yaml` is the default hermes profile config. It is
**not** managed by Home Manager — hermes-agent writes back to it at runtime
(e.g., `onboarding.seen`, `_config_version`). Do not manage it via
`home.file`; that would make it read-only and break hermes-agent writes.

Key settings to be aware of:

```yaml
matrix:
  require_mention: false    # must stay false; env var alone is not sufficient
                            # because config.extra takes priority over env vars
                            # in _parse_require_mention()
```

If this value reverts to `true` (e.g., after a config schema migration),
the bot will go silent in unmonitored rooms. Fix:

```bash
sed -i 's/^  require_mention: true$/  require_mention: false/' \
  /home/groot/.hermes/config.yaml
systemctl --user restart hermes-gateway
```

---

## context-mode plugin

`context-mode-hermes` (a hermes-agent plugin) and `context-mode` (its
companion Node CLI) are packaged in `hosts/hermes/llm-agents-overlay.nix` and
`hosts/hermes/groot-hm.nix`. Nix only puts the plugin on `PYTHONPATH` and the
CLI on `PATH` — activation is a manual edit to `/home/groot/.hermes/config.yaml`,
which stays hand-owned for the same reason as the rest of that file (see
"Runtime config" above).

Add both of the following to `config.yaml`:

```yaml
plugins:
  enabled:
    - context-mode        # REQUIRED - entry-point plugins are opt-in
mcp_servers:
  context-mode:
    command: context-mode
```

The `plugins.enabled` entry is required even though upstream's README does not
mention it: `hermes_cli/plugins.py` treats an absent `plugins.enabled` key as
"nothing enabled," and the `plugins.disabled` deny-list always wins over
`plugins.enabled` when both list the same plugin.

Then restart both gateway units so the new PYTHONPATH and config take effect:

```bash
systemctl --user restart hermes-gateway hermes-gateway-coding-local
```

### Runtime state

The plugin creates state that Nix does not declare or manage:

- `CONTEXT_MODE_DIR` (default `~/.local/share/hermes-context-mode`) — SQLite
  FTS5 knowledge base.
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
