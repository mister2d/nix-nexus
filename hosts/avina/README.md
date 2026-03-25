# avina — Matrix 2.0 LXC Container

avina is a Proxmox **LXC container** running NixOS. The full Matrix 2.0 stack
(Synapse, MAS, HAProxy, Coturn, LiveKit, cloudflared) is declared in this
flake and applied via `nixos-rebuild switch`.

---

## Prerequisites

**On your workstation:**

```bash
# site-config.nix must exist before building
cp hosts/avina/site-config.nix.example hosts/avina/site-config.nix
# Edit with real domains, Vault address, and cert domain
$EDITOR hosts/avina/site-config.nix
git add -f hosts/avina/site-config.nix   # stage the gitignored file for nix
```

---

## Container Setup (Proxmox)

Follow the NixOS LXC image guide:
<https://nixos.wiki/wiki/Proxmox_Linux_Container>

Key Proxmox settings for avina:
- **Type**: Unprivileged LXC (`proxmoxLXC.privileged = false`) — root inside the container maps to an unprivileged uid on the Proxmox host
- **Network**: Proxmox manages the interface (DHCP or static at hypervisor level).
  NixOS firewall runs inside the container; configure the Proxmox firewall as wide-open.
- **Storage**: Standard Proxmox volume — no ZFS configuration needed inside the container.
- **Ports**: Expose 22, 443, 3478, 5349, 8404 and UDP 49000–49999 at the Proxmox level.

---

## Deployment

Once the NixOS LXC container is running, copy the flake and switch:

```bash
# From your workstation — copy flake to container
rsync -av --exclude='.git' /path/to/nix-nexus/ root@avina:/etc/nixos/

# Inside the container (or via ssh)
cd /etc/nixos

# Populate the gitignored secrets file
cp hosts/avina/site-config.nix.example hosts/avina/site-config.nix
$EDITOR hosts/avina/site-config.nix

# Place Vault AppRole credentials (see "Vault Authentication" below)
install -dm 0700 /var/lib/secrets
printf '%s' '<role-id-uuid>'   | install -m 0600 /dev/stdin /var/lib/secrets/vault-role-id
printf '%s' '<secret-id-uuid>' | install -m 0600 /dev/stdin /var/lib/secrets/vault-secret-id

# Apply the configuration
nixos-rebuild switch --flake .#avina --impure
```

---

## Vault Authentication

vault-agent authenticates to Vault using **AppRole**, not an admin token or a
static `VAULT_TOKEN`. Two files must exist in `/var/lib/secrets/` before the
first boot:

| File | Content | Notes |
|---|---|---|
| `vault-role-id` | AppRole `role_id` UUID | Not a secret per se, but restrict read access |
| `vault-secret-id` | AppRole `secret_id` UUID | **Treat as a secret** — rotate if exposed |

Obtain them from Vault (as admin, from your workstation):

```bash
# Read the role-id (static per role)
vault read auth/approle/role/avina/role-id

# Generate a new secret-id
vault write -f auth/approle/role/avina/secret-id
```

**On the 96h token TTL**: this is `token_ttl` on the AppRole definition in
Vault, not a value placed in any file. vault-agent automatically renews the
live token before it expires. Set `secret_id_ttl = "0"` on the AppRole so the
on-disk secret-id never expires and survives reboots without manual rotation:

```bash
vault write auth/approle/role/avina \
  token_ttl=96h \
  token_max_ttl=96h \
  secret_id_ttl=0 \
  policies="avina"
```

Do **not** place an admin token here. The AppRole policy (`avina`) must have
`read` access to the following KV-v2 paths only:

- `kv-v2/data/letsencrypt/certificates/live/<certDomain>`
- `kv-v2/data/infrastructure/matrix/avina/*`
- `kv-v2/data/infrastructure/smtp`

---

## Runtime Secrets (vault-agent renders these on boot)

| Secret | Path | Consumer |
|---|---|---|
| AppRole role-id | `/var/lib/secrets/vault-role-id` | vault-agent bootstrap (persistent) |
| AppRole secret-id | `/var/lib/secrets/vault-secret-id` | vault-agent bootstrap (persistent) |
| TLS cert (HAProxy) | `/run/certs/haproxy.pem` | HAProxy — fullchain + key |
| TLS cert (Coturn) | `/run/certs/coturn-fullchain.pem` | Coturn |
| TLS key (Coturn) | `/run/certs/coturn.key` | Coturn |
| Synapse secrets | `/run/secrets/synapse-secrets.yaml` | Synapse `extraConfigFiles` |
| Synapse email | `/run/secrets/synapse-email.yaml` | Synapse `extraConfigFiles` |
| MAS config | `/run/secrets/mas-config.yaml` | matrix-authentication-service |
| Coturn secret | `/run/secrets/coturn-secret` | Coturn `use-auth-secret` |
| Coturn env | `/run/secrets/coturn-secret-env` | LiveKit TURN credentials |

All `/run/` paths are RAM-only and never persist across reboots. vault-agent
re-renders them on every boot and re-renders in-place whenever the upstream
KV version increments (automatic cert rotation).

---

## Post-Deploy Checks

```bash
# Federation
curl "https://federationtester.matrix.org/api/report?server_name=MATRIX_DOMAIN"

# Client API
curl https://MATRIX_DOMAIN/_matrix/client/versions

# Well-known
curl https://MATRIX_DOMAIN/.well-known/matrix/client | python3 -m json.tool

# MAS OIDC
curl https://MAS_DOMAIN/.well-known/openid-configuration

# LiveKit JWT service
curl https://MATRIX_DOMAIN/livekit/jwt/healthz

# Element Web
curl -I https://ELEMENT_DOMAIN

# Certs from Vault
ls -la /run/certs/

# No secrets in store
grep -rn "client_secret\|VAULT_TOKEN\|encryption" /nix/store 2>/dev/null | grep -v ".drv:"
```
