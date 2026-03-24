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
- **Type**: Privileged LXC
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

# Place Vault AppRole credentials
install -m 0600 /dev/stdin /var/lib/secrets/vault-token.env <<'EOF'
VAULT_TOKEN=<your-vault-token>
EOF

# Apply the configuration
nixos-rebuild switch --flake .#avina --impure
```

---

## Secrets

All runtime secrets come from Vault via vault-agent:

| Secret | Path | Consumer |
|---|---|---|
| `VAULT_TOKEN` | `/var/lib/secrets/vault-token.env` | vault-agent bootstrap |
| TLS cert (HAProxy) | `/run/certs/haproxy.pem` | vault-agent → HAProxy |
| TLS cert (Coturn) | `/run/certs/coturn-fullchain.pem` | vault-agent → Coturn |
| TLS key (Coturn) | `/run/certs/coturn.key` | vault-agent → Coturn |
| Synapse config | `/run/secrets/synapse-secrets.yaml` | Synapse extraConfigFiles |
| MAS config | `/run/secrets/mas-config.yaml` | MAS service |

vault-agent fetches all of the above at boot from
`kv-v2/letsencrypt/certificates/live/<certDomain>` and the corresponding
Synapse/MAS KV paths.

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
