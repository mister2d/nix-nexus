# Provisioning a Service Account Bot on a MAS-Delegated Homeserver

## Context and Constraints

This guide covers provisioning a Matrix bot account on a homeserver where
Synapse has delegated all authentication to **Matrix Authentication Service
(MAS)** via MSC3861. The key operational constraints this creates:

- Synapse's password login is disabled. The `/_matrix/client/*/login` endpoint
  is intercepted by MAS, not Synapse.
- There is no Matrix-native credential database to add users to directly.
- The upstream identity provider (e.g. Keycloak with passkey enforcement)
  is not suitable for non-interactive bot accounts.
- The `password` field in OpenClaw's Matrix channel config cannot be used —
  MAS has no password auth path to call.

The only viable credential for a bot in this architecture is a **MAS
compatibility token** (`mct_...` / `syt_...`), issued directly by `mas-cli`
against the MAS database. The bot user itself is a **MAS-local account** with
no upstream provider binding — intentionally orphaned from the SSO chain.

---

## Architecture: Why a MAS-Local Account

In an MSC3861 deployment, MAS is the sole authority for user identity. Users
normally authenticate via an upstream OIDC provider (Keycloak), which MAS
brokers. For a bot, this flow is inappropriate:

- The upstream IdP may enforce interactive authentication (passkeys, MFA).
- There is no browser context to complete an OIDC Authorization Code flow.
- Coupling a bot credential to an IdP account creates unnecessary operational
  dependency on that IdP's availability.

A MAS-local account exists only in MAS's PostgreSQL database. It has no
password and no `upstream_oauth2` provider mapping. It cannot be logged into
via any SSO flow. Its sole authentication path is the compat token issued at
provisioning time. This is the correct model for a non-human service identity
on an SSO-only homeserver.

---

## Prerequisites

- SSH access to the host running `matrix-authentication-service`.
- The `mas-cli` binary, co-located with the MAS service package.
- The MAS config rendered and accessible (e.g. `/run/secrets/mas-config.yaml`).
- `vault` CLI available if storing the resulting token in Vault KV.

Locate the binary from the active service unit:

```sh
systemctl cat matrix-authentication-service | grep ExecStart
# Example output:
# ExecStart=/nix/store/<hash>-matrix-authentication-service-1.13.0/bin/mas-cli \
#   server --config /run/secrets/mas-config.yaml
```

Set a shell variable for convenience:

```sh
MAS_CLI=/nix/store/<hash>-matrix-authentication-service-1.13.0/bin/mas-cli
MAS_CONFIG=/run/secrets/mas-config.yaml
```

---

## Execution Context

`mas-cli manage` commands require two conditions to succeed:

**PostgreSQL peer authentication.** MAS's config connects to Postgres using
Unix socket peer auth. The OS user running `mas-cli` must match the database
role — typically `matrix-authentication-service`. Running as `root` fails
this check.

**Secret file access.** If the MAS config is group-gated (e.g. mode `0640`,
group `matrix-secrets`), the executing process needs that supplementary group.
`sudo -u` does not inherit `SupplementaryGroups` defined in the systemd unit;
it only switches the primary user and group.

The correct invocation pattern is `systemd-run`, which applies the full
execution context of the service unit:

```sh
systemd-run \
  --uid=matrix-authentication-service \
  --gid=matrix-authentication-service \
  --property=SupplementaryGroups=matrix-secrets \
  --property=WorkingDirectory=/var/lib/matrix-authentication-service \
  --wait --collect \
  $MAS_CLI --config $MAS_CONFIG manage <subcommand> [args]
```

All `manage` operations in this guide use this pattern.

---

## Step 1: Register the Bot User

Register the bot as a MAS-local account. Do not set a password and do not
add an upstream provider mapping (`-m`). The account will be unreachable via
any browser login flow.

```sh
systemd-run \
  --uid=matrix-authentication-service \
  --gid=matrix-authentication-service \
  --property=SupplementaryGroups=matrix-secrets \
  --property=WorkingDirectory=/var/lib/matrix-authentication-service \
  --wait --collect \
  $MAS_CLI --config $MAS_CONFIG manage register-user \
  --yes \
  --no-admin \
  --display-name "bottyMouth" \
  bottymouth
```

Flag notes:
- `--yes` — skips interactive prompts; required for non-terminal invocation.
- `--no-admin` — bot accounts must not have MAS admin privileges.
- No `-p` — no password. The account has no credential until the compat token
  is issued.
- No `-m` — no upstream provider mapping. Adding one is only appropriate if
  you want an SSO identity to claim this account later; a bot account should
  not be claimable.

A clean exit (`status=0/SUCCESS`) confirms the user exists in MAS's database.

### Verify (optional)

```sh
systemd-run \
  --uid=matrix-authentication-service \
  --gid=matrix-authentication-service \
  --property=SupplementaryGroups=matrix-secrets \
  --property=WorkingDirectory=/var/lib/matrix-authentication-service \
  --wait --collect \
  $MAS_CLI --config $MAS_CONFIG manage list-admin-users
# bottymouth should NOT appear here
```

---

## Step 2: Issue a Compatibility Token

The compat token is the bot's sole credential. It authenticates directly
against MAS and is accepted by Synapse via the MSC3861 token validation path.

```sh
systemd-run \
  --uid=matrix-authentication-service \
  --gid=matrix-authentication-service \
  --property=SupplementaryGroups=matrix-secrets \
  --property=WorkingDirectory=/var/lib/matrix-authentication-service \
  --wait --collect \
  $MAS_CLI --config $MAS_CONFIG manage issue-compatibility-token \
  bottymouth
```

The token is emitted to stdout and journald. Retrieve it from the journal
immediately if it does not appear inline:

```sh
journalctl -u <unit-name> --no-pager
# Look for: INFO ... Compatibility token issued: mct_...
```

> **The token is shown exactly once.** `mas-cli` does not provide a retrieval
> command. If the token is lost before storage, issue a new one — the previous
> session remains active until explicitly killed with `manage kill-sessions`.

---

## Step 3: Store the Token in Vault

Do not write the token to disk, config files, or environment files that
persist across reboots. Store it in Vault KV under the deployment's existing
secret path convention:

```sh
vault kv put kv-v2/infrastructure/matrix/<host>/openclaw \
  bottymouth_access_token="mct_..."
```

Add a vault-agent template to render it to a RAM-only path on boot:

```hcl
template {
  contents = <<-EOT
    {{ with secret "kv-v2/data/infrastructure/matrix/<host>/openclaw" -}}
    {{ .Data.data.bottymouth_access_token }}
    {{- end }}
  EOT
  destination          = "/run/secrets/openclaw-matrix-token"
  perms                = "0640"
  error_on_missing_key = true
}
```

The rendered path is RAM-only (`tmpfs`), wiped on reboot, and re-rendered by
vault-agent on each boot. The token never touches the Nix store or any
persistent filesystem path.

Consume it in the OpenClaw service unit as an environment variable:

```
MATRIX_BOTTYMOUTH_ACCESS_TOKEN=$(cat /run/secrets/openclaw-matrix-token)
```

Or reference the env var directly in the OpenClaw config if the service unit
sources the rendered file.

---

## Step 4: Configure OpenClaw

With the token available via environment, the OpenClaw channel config does
not need to contain any credential. The named account `bottyMouth` maps to
env var prefix `MATRIX_BOTTYMOUTH_` (camelCase normalized to uppercase,
non-alphanumeric separators become `_`).

```json
{
  "channels": {
    "matrix": {
      "enabled": true,
      "defaultAccount": "bottyMouth",
      "accounts": {
        "bottyMouth": {
          "name": "bottyMouth",
          "homeserver": "https://matrix.example.com",
          "userId": "@bottymouth:example.com",
          "encryption": true,
          "allowPrivateNetwork": true,
          "autoJoin": "allowlist",
          "autoJoinAllowlist": ["!<roomid>:example.com"],
          "groupPolicy": "allowlist",
          "groupAllowFrom": ["@admin:example.com"],
          "groups": {
            "!<roomid>:example.com": {
              "requireMention": true
            }
          }
        }
      }
    }
  }
}
```

Design decisions:
- `allowPrivateNetwork: true` — required for any homeserver resolving to a
  LAN address, Tailscale IP, or internal hostname. OpenClaw blocks these by
  default as an SSRF control.
- `autoJoin: "allowlist"` — the bot only joins rooms explicitly listed. Never
  use `"always"` on a shared homeserver.
- `autoJoinAllowlist` uses stable room IDs (`!room:server`), not aliases.
  OpenClaw does not trust alias state claimed by the invited room.
- `groupPolicy: "allowlist"` with `requireMention: true` — the bot only
  processes messages in allowlisted rooms and only when explicitly mentioned.
  This prevents accidental or malicious message injection.

---

## Step 5: Bootstrap E2EE (Encrypted Rooms)

If the bot will participate in encrypted rooms, E2EE must be bootstrapped
after first gateway start.

```sh
# Bootstrap cross-signing and key backup
openclaw matrix verify bootstrap --account bottyMouth --verbose

# Confirm the device is owner-signed (not just locally trusted)
openclaw matrix verify status --account bottyMouth --verbose

# Confirm room-key backup is healthy
openclaw matrix verify backup status --account bottyMouth --verbose
```

The verification status output must show:

```
Verified by owner: yes
```

`Locally trusted: yes` alone is insufficient — the bot cannot decrypt
messages in encrypted rooms until cross-signing verification is complete.

### Known Failure Mode: Interactive Auth on Key Upload

Bootstrap uploads cross-signing keys to Synapse via
`POST /_matrix/client/v3/keys/device_signing/upload`. On some Synapse/MAS
configurations this endpoint requires interactive auth. OpenClaw attempts
the upload unauthenticated, then falls back to `m.login.dummy`, then
`m.login.password`. Since the bot account has no password, the password
fallback is unavailable.

If bootstrap fails at this step, the error will indicate an interactive auth
rejection. Resolution options:

1. Check whether the MAS/Synapse combination requires interactive auth for
   this endpoint at all — newer MAS versions may not.
2. Pre-authorize via MAS admin if an admin session bypass exists.
3. Run `--force-reset-cross-signing` after resolving the auth gap to discard
   and recreate the cross-signing identity.

---

## Token Lifecycle and Rotation

The compat token has no built-in expiry but is bound to a MAS compat session.
It remains valid until:

- The session is explicitly killed via `manage kill-sessions`.
- The user is locked via `manage lock-user`.
- The Vault secret is rotated and the old token is revoked.

To rotate:

```sh
# Kill all existing sessions for the bot
systemd-run \
  --uid=matrix-authentication-service \
  --gid=matrix-authentication-service \
  --property=SupplementaryGroups=matrix-secrets \
  --property=WorkingDirectory=/var/lib/matrix-authentication-service \
  --wait --collect \
  $MAS_CLI --config $MAS_CONFIG manage kill-sessions bottymouth

# Issue a new token
# (repeat Step 2)

# Update Vault
vault kv put kv-v2/infrastructure/matrix/<host>/openclaw \
  bottymouth_access_token="mct_<new>"

# vault-agent re-renders /run/secrets/openclaw-matrix-token automatically
# Restart OpenClaw to pick up the new token
openclaw gateway restart
```

---

## Security Properties

| Property | Mechanism |
|---|---|
| No password credential | Account registered with no `-p` flag |
| No SSO claimability | No `-m` upstream provider mapping |
| Token not in Nix store | Vault KV → vault-agent → RAM-only tmpfs |
| Token not in config files | Env var sourced from rendered secret path |
| Bot cannot self-elevate | Registered with `--no-admin` |
| Room scope limited | `autoJoin: "allowlist"` + explicit room ID |
| Message scope limited | `requireMention: true` per room |
| Private network SSRF | `allowPrivateNetwork: true` opt-in per account |
