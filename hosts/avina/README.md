# avina — Matrix 2.0 LXC Container

avina is a Proxmox **LXC container** running NixOS. The full Matrix 2.0 stack
(Synapse, MAS, HAProxy, Coturn, LiveKit, cloudflared) is declared in this
flake and applied via `nixos-rebuild switch`.

---

## Stack Versions

Versions are pinned in `modules/services/matrix/versions.nix` and asserted at
build time — `nixos-rebuild` fails with a descriptive error if any resolved
package drifts from the declared version.

Matrix-facing packages are sourced from the `pkgs-stable` overlay
(`nixos-25.11 @ 812b3986fd15`). Infrastructure packages come from the primary
nixpkgs input (`nixos-25.11 @ addf7cf5f383`). Both track the same NixOS stable
channel at different commits.

| Component | Version | Role | nixpkgs source |
|---|---|---|---|
| NixOS | 25.11 | Host OS | `addf7cf5f383` |
| Synapse | 1.149.1 | Matrix homeserver (MSC3861 delegated auth) | pkgs-stable `812b3986fd15` |
| MAS | 1.13.0 | OIDC bridge — MSC3861 native OIDC provider | pkgs-stable `812b3986fd15` |
| Element Web | 1.12.10 | Matrix web client | pkgs-stable `812b3986fd15` |
| Element Call | 0.11.1 | WebRTC calling — MSC4143 RTC foci | pkgs-stable `812b3986fd15` |
| LiveKit | 1.9.4 | WebRTC SFU (media server) | pkgs-stable `812b3986fd15` |
| lk-jwt-service | 0.4.0 | LiveKit JWT token auth service | pkgs-stable `812b3986fd15` |
| Coturn | 4.9.0 | STUN/TURN server — RFC 5766/8656 | pkgs-stable `812b3986fd15` |
| PostgreSQL | 16.13 | Database backend (Synapse + MAS) | pkgs-stable `812b3986fd15` |
| HAProxy | 3.2.9 | TLS termination + reverse proxy | `addf7cf5f383` |
| Vault | 1.21.1 | Secrets backend (vault-agent on avina) | `addf7cf5f383` |
| darkhttpd | 1.17 | Static file server (well-known, ToS) | `addf7cf5f383` |
| cloudflared | — | Zero-trust ingress tunnel (**external host**) | not on avina |

> **cloudflared** runs on a separate host at the network edge, not on avina.
> Its version is not asserted here. The tunnel forwards HTTPS inbound to
> `avina.home.lan:443`.

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
- **Ports**: Expose 22, 443, 3478, 5349, 8404, UDP 49000–49999, and UDP 50100–50200 at the Proxmox level.

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
| TLS cert (HAProxy) | `/run/certs/haproxy.pem` | HAProxy — fullchain + key combined |
| TLS cert (Coturn) | `/run/certs/coturn-fullchain.pem` | Coturn |
| TLS key (Coturn) | `/run/certs/coturn.key` | Coturn |
| Synapse secrets | `/run/secrets/synapse-secrets.yaml` | Synapse `extraConfigFiles` |
| Synapse email | `/run/secrets/synapse-email.yaml` | Synapse `extraConfigFiles` |
| MAS config | `/run/secrets/mas-config.yaml` | matrix-authentication-service |
| MAS EC signing key | `/run/secrets/mas-signing-ec.key` | matrix-authentication-service |
| MAS RSA signing key | `/run/secrets/mas-signing-rsa.key` | matrix-authentication-service |
| Coturn secret | `/run/secrets/coturn-secret` | Coturn `use-auth-secret` |
| Coturn env | `/run/secrets/coturn-secret-env` | Coturn HMAC secret (env format; also rendered for legacy use) |

All `/run/` paths are RAM-only and never persist across reboots. vault-agent
re-renders them on every boot and re-renders in-place whenever the upstream
KV version increments (automatic cert rotation).

---

## MAS Signing Keys

MAS requires signing keys to issue JWTs at the token endpoint (`POST /oauth2/token`).
Two keys are configured — one ECDSA, one RSA — for the following reasons:

**ECDSA P-384 (primary):** The preferred signing key. ES384 provides equivalent or
stronger security than RSA at a fraction of the key size, with better resistance to
timing side-channels. Clients that advertise ES384 support will receive tokens signed
with this key.

**RSA-4096 (compliance):** The OpenID Connect Core specification (RFC 7517) mandates
that servers implement RS256, making at least one RSA key a hard interoperability
requirement. RSA-4096 is used rather than the more common RSA-2048 to maximise the
strength of the compliance key while accepting its higher computational cost.

### Key Format Requirement

MAS 1.13.0's underlying Rust crypto parsers require **legacy PEM formats**. Despite
PKCS#8 being listed as supported in the documentation, PKCS#8-wrapped keys fail with
`Unsupported format` at startup. Use the following generation commands exactly:

```bash
# ECDSA P-384 — SEC1 format (BEGIN EC PRIVATE KEY)
openssl ecparam \
  -name secp384r1 \
  -genkey \
  -noout \
  -out /dev/shm/ec_private_key.pem

# RSA-4096 — PKCS#1 format (BEGIN RSA PRIVATE KEY)
openssl genrsa \
  -out /dev/shm/rsa_private_key.pem 4096

# Seed Vault (use =@ to preserve exact bytes including newlines)
vault kv patch kv-v2/infrastructure/matrix/avina/mas \
  signing_key_ec_pem=@/dev/shm/ec_private_key.pem \
  signing_key_rsa_pem=@/dev/shm/rsa_private_key.pem

# Wipe from memory-backed storage
rm /dev/shm/ec_private_key.pem /dev/shm/rsa_private_key.pem
```

> **Warning:** Do not regenerate signing keys after production use. Rotation
> invalidates all active sessions and issued tokens — every logged-in user is
> forcibly logged out. Treat these keys with the same care as the encryption
> secret.

Both keys are stored in Vault KV-v2 at
`kv-v2/infrastructure/matrix/avina/mas` and rendered to `/run/secrets/` by
vault-agent on every boot. The rendered files are mode `0640`, group
`matrix-secrets`. MAS reads them via `key_file:` entries in its config.

---

## Security Posture

### Ingress

avina sits entirely on the **internal LAN** (`avina.home.lan`). It is not directly
reachable from the internet. HTTP/S ingress is brokered by a **Cloudflare Tunnel
connector** (`cloudflared`) running on a separate node near the network edge — not on
avina itself. That connector maintains a persistent outbound tunnel to Cloudflare's
edge and forwards incoming requests inward to `avina.home.lan:443`.

```
Internet client
  │ HTTPS (Cloudflare edge certificate)
  ▼
Cloudflare Edge  ←──── outbound tunnel maintained by external cloudflared connector
  │ re-encrypted HTTPS → avina.home.lan:443
  ▼
HAProxy :443 on avina (Let's Encrypt wildcard cert; internal LAN only)
```

#### TLS Architecture — Double Encryption

Two independent TLS sessions are in play:

| Leg | Certificate | Notes |
|---|---|---|
| Browser → Cloudflare | Cloudflare-managed certificate | Valid, browser-trusted; Cloudflare handles renewal |
| Cloudflare connector → avina:443 | Let's Encrypt wildcard (`*.novuscotia.com`) | Valid cert; hostname verification disabled (see below) |

The Let's Encrypt certificate on avina is issued for the public domain
(`*.novuscotia.com`) but cloudflared connects to the host via its LAN name
(`avina.home.lan`). Because the presented certificate's Subject Alternative Names
do not include `avina.home.lan`, cloudflared is configured with `noTLSVerify: true`
to suppress hostname mismatch errors.

**Security assessment of `noTLSVerify: true` (rating: B+):** Traffic between the
cloudflared connector and avina is still encrypted in transit — the session is
TLS-protected against passive eavesdropping. The weakened guarantee is that an
active attacker with access to the internal LAN segment could present a fraudulent
certificate and cloudflared would not detect the substitution. In this deployment
the risk is accepted because (a) both nodes are on a trusted private LAN, (b) the
originating cloudflared host is operator-controlled, and (c) the path is
LAN-local and not internet-routable. The risk could be eliminated by configuring
split-horizon internal DNS to resolve `avina.novuscotia.com` to the LAN IP,
allowing cloudflared to verify the cert against the correct hostname.

#### Certificate Lifecycle

The Let's Encrypt wildcard cert is renewed by an external `certbot` process
independent of avina. On renewal, certbot writes the new certificate into
**Vault KV-v2**. vault-agent on avina watches that KV path; on version increment
it re-renders the HAProxy combined PEM (`/run/certs/haproxy.pem`) and the
Coturn files, then signals the respective services to reload — zero-downtime
rotation with no manual intervention on avina.

#### Port Exposure

avina's firewall permits the following on all interfaces (including the LAN):

| Port | Protocol | Service | Internet-facing? |
|---|---|---|---|
| 22 | TCP | OpenSSH | LAN only; password auth disabled; SSH CA enforced |
| 443 | TCP | HAProxy (HTTPS) | LAN only; reachable by cloudflared connector |
| 3478 | TCP+UDP | Coturn STUN/TURN | Yes — NAT-forwarded at edge router |
| 5349 | TCP+UDP | Coturn TURNS/TLS | Yes — NAT-forwarded at edge router |
| 49000–49999 | UDP | Coturn relay range | Yes — NAT-forwarded at edge router |
| 50100–50200 | UDP | LiveKit WebRTC media | Yes — NAT-forwarded at edge router |

WebRTC ICE requires direct UDP reachability. Clients on standard networks connect
directly to LiveKit on UDP 50100–50200 (the preferred ICE path). Clients behind
strict NAT use Coturn TURN relay as a fallback; Coturn can relay to LiveKit's public
IP on those ports. All other services remain LAN-internal.

### Authentication

Synapse password authentication is fully disabled. All login flows pass through MAS
(Matrix Authentication Service), which implements the MSC3861 native OIDC delegation
protocol. MAS authenticates upstream to a self-hosted Keycloak instance. Clients
(Element Web, Element X) never speak directly to Keycloak — MAS brokers the identity
and issues its own access and refresh tokens to clients.

This architecture means:
- A single Keycloak account governs access to the Matrix homeserver.
- Session revocation in Keycloak propagates to Matrix via MAS token invalidation.
- No Matrix-native password database exists to be compromised.

### Secrets Model

No secrets are baked into the NixOS configuration or the Nix store. All runtime
secrets — TLS certificates, database credentials, OIDC client secrets, signing keys —
are pulled from **Vault KV-v2** by `vault-agent` on each boot and rendered to
**RAM-only paths** (`/run/secrets/`, `/run/certs/`). These paths are backed by tmpfs
and are wiped on every reboot.

Access to `/run/secrets/` is gated by the `matrix-secrets` group (directory mode
`0750`). Each service that needs secrets is given `matrix-secrets` as a supplementary
group via the vault-secrets module. Individual secret files are mode `0640`.

vault-agent authenticates to Vault using AppRole. The `secret_id` on disk
(`/var/lib/secrets/vault-secret-id`) has `secret_id_ttl=0` so it survives reboots
without manual intervention. The live Vault token has a 96-hour TTL and is
automatically renewed by vault-agent before expiry.

### Coturn SSRF Prevention

Coturn's `denied-peer-ip` list covers all RFC-1918 private ranges, loopback
(`127.0.0.0/8`), link-local (`169.254.0.0/16`), and CGNAT (`100.64.0.0/10`). This
prevents a malicious client from using the TURN relay as a proxy to reach internal
services on avina's localhost or the Proxmox host network.

---

## TODO: Future Implementation

### Telemetry / Metrics

MAS exposes Prometheus metrics at its internal listener. Wire up a Prometheus scrape job
targeting `127.0.0.1:8182/metrics` and add a Grafana dashboard for token issuance rate,
login latency, and rate-limit hits. HAProxy already exposes `*:8404/metrics` via
`prometheus-exporter`.

### Google Upstream OIDC

To allow known associates with Google accounts to access the homeserver, add a second
upstream OIDC provider to `masConfigTmpl` alongside the Keycloak provider. Google's
`brand_name: google` is natively supported by MAS for branded login buttons. Requires
creating an OAuth 2.0 client in Google Cloud Console and seeding `client_id` /
`client_secret` into Vault at `masPath` (e.g. `oidc_google_client_id`,
`oidc_google_client_secret`). Restrict `hd` (hosted domain) if limiting to specific
Google Workspace domains.

### Custom Theming / Branding

MAS 1.x theming is controlled by the `branding` config section (already configured:
`service_name`, `tos_uri`) and via CSS overrides served at a custom `templates_path`.
Future work: add a `policy_uri` and `imprint` once those pages are authored; investigate
the MAS `custom_templates` mechanism for deeper UI customisation (logo, colour palette).
Upstream issue tracking MAS theming: element-hq/matrix-authentication-service#2209.

---

## Post-Deploy Checks

```bash
# Federation
curl "https://federationtester.matrix.org/api/report?server_name=MATRIX_DOMAIN"

# Client API
curl https://MATRIX_DOMAIN/_matrix/client/versions

# Well-known (client discovery — must include rtc_foci, m.authentication)
curl https://MATRIX_DOMAIN/.well-known/matrix/client | python3 -m json.tool

# Well-known (federation discovery — must return {"m.server":"<domain>:443"})
curl https://MATRIX_DOMAIN/.well-known/matrix/server

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
