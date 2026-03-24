# Avina — Matrix 2.0 Communications Server

Avina is a public-facing Matrix 2.0 homeserver built on NixOS. It implements the full
modern Matrix stack: native OIDC authentication, MatrixRTC video/audio, and WebRTC media
relay — all behind a single HAProxy ingress delivered via Cloudflare tunnel.

## Architecture

| Component | Role |
| :--- | :--- |
| **Synapse** | Matrix homeserver |
| **Matrix Authentication Service (MAS)** | Native OIDC provider; delegates upstream auth to Keycloak |
| **Element Web** | Primary web client |
| **Element Call** | MatrixRTC video/audio frontend |
| **LiveKit** | WebRTC SFU for MatrixRTC media |
| **Coturn** | STUN/TURN relay for clients behind restrictive NAT |
| **HAProxy** | Sole TLS terminator and HTTP/S reverse proxy |
| **Cloudflared** | Tunnel to Cloudflare edge — ports 80/443 are not exposed directly |

## Secret Management

Avina enforces a **zero secrets in Nix store** policy. All cryptographic material lives
in Vault and is rendered into the memory-backed `/run/secrets/` directory at boot by
`vault-agent`. Nothing sensitive persists across reboots except the Vault AppRole
credential pair that authorises the initial fetch.

### Credential hierarchy

| Level | Material | Purpose | Survives reboot? |
| :--- | :--- | :--- | :--- |
| **Operator** | Admin Vault token | Runs `deploy-avina.sh` once | No |
| **Host** | AppRole (role-id + secret-id) | Self-bootstraps at every boot | Yes — `/var/lib/secrets/` |

### Boot sequence

1. `vault-agent-init` (oneshot) authenticates via AppRole and renders all secrets and
   TLS certificates into `/run/secrets/` and `/run/certs/`.
2. `vault-agent` (daemon) takes over, maintaining token renewal and re-rendering secrets
   whenever upstream KV versions increment.
3. Coturn, HAProxy, Synapse, MAS, and LiveKit are all ordered after `vault-agent-init`
   via systemd dependencies — no service starts before secrets are present.

### Build-time deployment values

Domain names and the Vault address are **not secrets** but are kept out of the repository
for OPSEC. They live in a gitignored `site-config.nix` file created on the server before
deployment. See `site-config.nix.example` for the required keys and their relationship to
the Vault KV `config` tier.

---

## Installation — Two-Stage UEFI Deployment

### Prerequisites

- VM with UEFI/OVMF firmware, `/dev/sda` as the primary disk
- 12 GB RAM minimum, 4 vCPUs
- NixOS installation ISO (x86_64)
- Vault instance reachable from the VM at boot

---

### Stage 1 — ZFS Bootstrap

Boot the NixOS ISO, then from the live environment:

```bash
# Clone the repository
git clone https://github.com/mister2d/nix-nexus.git
cd nix-nexus

# Partition the disk and create the ZFS pool 'avina'
# WARNING: this wipes /dev/sda
sudo nix run github:nix-community/disko -- --mode disko ./hosts/avina/disko.nix

# Install the bootstrap profile
sudo nixos-install --flake .#avina-bootstrap
```

Reboot. The system comes up as `avina-bootstrap` with SSH (cert auth), tmux, and the
repository intact at its install path. No Matrix services are present yet.

---

### Stage 2 — Full Matrix Deployment

SSH into the bootstrap system and work inside a tmux session. The `nixos-rebuild switch`
at the end of the deployment script transitions the network backend from NetworkManager to
systemd-networkd, causing a brief connectivity blip. tmux ensures the switch completes
uninterrupted even if the SSH session drops.

```bash
tmux new -s deploy
cd /path/to/nix-nexus
```

Create `site-config.nix` from the example template and fill in real values. This file is
gitignored and must be created manually on every fresh install — it is never committed.

```bash
cp hosts/avina/site-config.nix.example hosts/avina/site-config.nix
$EDITOR hosts/avina/site-config.nix
```

The values in `site-config.nix` must align with what you seed into Vault. Specifically,
`matrixDomain` must match `matrix_domain` in `kv-v2/infrastructure/matrix/avina/config`,
and `masDomain` must match `auth_domain`.

Run the deployment script as root:

```bash
sudo ./hosts/avina/deploy-avina.sh
```

The script executes the following sequence without further manual steps:

1. Prompts for the Vault address and an admin token.
2. Creates the `avina` Vault policy and AppRole.
3. Prompts interactively to seed the three-tier KV structure
   (`config`, `synapse`, `mas`) if any keys are missing.
4. Writes the AppRole `role-id` and `secret-id` to `/var/lib/secrets/` — the persistent
   Master Key that authorises every subsequent boot.
5. Runs `nixos-rebuild switch --flake .#avina --impure`.

On the switch, the hostname changes to `avina`, systemd-networkd takes over `ens18`,
and `vault-agent-init` runs before any Matrix service is allowed to start.

---

## Observability

HAProxy captures Cloudflare edge metadata on every request and propagates it to backends:

- `CF-Ray` → `X-Cloudflare-Ray` — unique edge request ID for end-to-end tracing
- `CF-Connecting-IP` — real client IP; set as the HAProxy source and `X-Forwarded-For`
- `CF-IPCountry` → `X-Cloudflare-Country` — client country code

Synapse trusts `127.0.0.1` as a proxy and resolves the real client IP from
`X-Forwarded-For` accordingly.

---

## Persistence — ZFS Datasets

Each stateful component is isolated to its own ZFS dataset for atomic snapshot and
restore:

| Dataset | Path |
| :--- | :--- |
| `avina/postgresql` | `/var/lib/postgresql` |
| `avina/matrix-synapse` | `/var/lib/matrix-synapse` |
| `avina/matrix-authentication-service` | `/var/lib/matrix-authentication-service` |
| `avina/secrets` | `/var/lib/secrets` — Vault AppRole (Master Key) |

---

## Ongoing Maintenance

```bash
# Apply a configuration change
sudo nixos-rebuild switch --flake .#avina --impure

# Rotate TLS certificates (vault-agent re-renders on KV version increment)
# Update the cert in Vault; vault-agent detects the version change automatically.

# View secret rendering status
journalctl -u vault-agent-init -u vault-agent
```
