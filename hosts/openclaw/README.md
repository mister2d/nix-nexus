# openclaw — AI Agent LXC Container

openclaw is a Proxmox **LXC container** running NixOS. It acts as an execution environment for the `openclaw` AI agent ecosystem, tethered strongly into the tailscale mesh network. All configuration is declared in this flake and applied via `nixos-rebuild switch`.

---

## Stack Versions

Openclaw straddles two channels dynamically to ensure strict infrastructural reliability while fetching the bleeding-edge components required for its agent functionality.

Agent-facing packages (`openclaw`, `tailscale`) are sourced natively from the updated `nixpkgs-unstable` overlay. Base utilities (`nodejs_24`, `python314`) and system elements track the repository's pinned NixOS stable branch.

| Component | Role | nixpkgs source |
|---|---|---|
| NixOS | Host OS | `pkgs` (stable) |
| openclaw | Agent environment and CLI | `nixpkgs-unstable` (via overlay) |
| tailscale | Zero-trust mesh VPN | `nixpkgs-unstable` (via overlay) |
| nodejs_24 | Core NPM execution layer | `pkgs` (stable) |
| python314 | Core Py scripts execution layer | `pkgs` (stable) |
| vault | Secrets backend (vault-agent) | `pkgs` (stable) |

> **Insecure Package Waivers:** The `openclaw` project is marked insecure upstream by Nixpkgs maintainers because it uses LLMs to parse untrusted content, exposing it to prompt injection risks while possessing broad system capabilities. To allow evaluation, `openclaw-2026.4.2` is explicitly allowed via `config.permittedInsecurePackages` inside both the host configuration and the unstable overlay map in `flake.nix`.

---

## Container Setup (Proxmox)

Follow the NixOS LXC image guide:
<https://nixos.wiki/wiki/Proxmox_Linux_Container>

Key Proxmox settings for openclaw:
- **Type**: Unprivileged LXC (`proxmoxLXC.privileged = false`) — root inside the container maps to an unprivileged uid on the Proxmox host to limit the blast radius of any prompt injection escape.
- **Network**: Proxmox manages the interface. DHCP is obtained declaratively via `systemd-networkd`.
- **Storage**: Standard Proxmox volume.

---

## Deployment

Once the NixOS LXC container is running, copy the flake and switch:

```bash
# From your workstation — copy flake to container
rsync -av --exclude='.git' /path/to/nix-nexus/ root@openclaw:/etc/nixos/

# Inside the container (or via ssh)
cd /etc/nixos

# Place Vault AppRole credentials (see "Vault Authentication" below)
install -dm 0700 /var/lib/secrets
printf '%s' '<role-id-uuid>'   | install -m 0600 /dev/stdin /var/lib/secrets/vault-role-id
printf '%s' '<secret-id-uuid>' | install -m 0600 /dev/stdin /var/lib/secrets/vault-secret-id

# Apply the configuration
nixos-rebuild switch --flake .#openclaw --impure
```

---

## Vault Authentication

`vault-agent` authenticates to Vault using **AppRole**, not an admin token or a static `VAULT_TOKEN`. Two files must exist in `/var/lib/secrets/` before the first boot:

| File | Content | Notes |
|---|---|---|
| `vault-role-id` | AppRole `role_id` UUID | Not a secret per se, but restrict read access |
| `vault-secret-id` | AppRole `secret_id` UUID | **Treat as a secret** — rotate if exposed |

Obtain them from Vault (as admin, from your workstation):

```bash
# Read the role-id (static per role)
vault read -field=role_id auth/approle/role/openclaw/role-id > /var/lib/secrets/vault-role-id

# Generate a new secret-id
vault write -f -field=secret_id auth/approle/role/openclaw/secret-id > /var/lib/secrets/vault-secret-id
```

**On the 96h token period**: `vault-agent` natively utilizes a periodic token via `token_period=96h` on the AppRole definition in Vault. This allows the vault-agent to automatically renew the live token constantly as long as it continues heartbeating, preventing expiration without requiring a strict max TTL override.

```bash
vault write auth/approle/role/openclaw \
  token_period=96h \
  policies="openclaw-policy"
```

Do **not** place an admin token here. The AppRole policy (`openclaw-policy`) must have `read` access to the following KV-v2 path only:
- `kv-v2/data/infrastructure/tailscale`

---

## Runtime Secrets (vault-agent renders these on boot)

| Secret | Path | Consumer |
|---|---|---|
| AppRole role-id | `/var/lib/secrets/vault-role-id` | vault-agent bootstrap (persistent) |
| AppRole secret-id | `/var/lib/secrets/vault-secret-id` | vault-agent bootstrap (persistent) |
| Tailscale Auth | `/run/secrets/tailscale.key` | `tailscaled` daemon startup |

The `/run/` path is RAM-only and never persists across reboots. `vault-agent` re-renders it on every boot immediately before `tailscaled` launches.

---

## Security Posture

No secrets are baked into the NixOS configuration or the Nix store. All runtime credentials—including the Tailscale authentication payload—are pulled from **Vault KV-v2** by `vault-agent` on each boot and rendered to **RAM-only paths** (`/run/secrets/`). 

### Terminal Environment

Even if connected via disaster-recovery fallback mechanisms outside of standard user shells, the `tmux` interface provides identical aesthetics natively handled at the host level in `default.nix`. Home Manager controls the robust configuration tree for the automated `groot` execution user (injecting custom `.bashrc`, neovim integrations, and custom prompt styles).
