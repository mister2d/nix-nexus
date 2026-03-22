# Avina: Matrix 2.0 Communications Server

Avina is a high-performance, secure, and fully public **Matrix 2.0** homeserver built on NixOS. It leverages modern Matrix standards (OIDC, MatrixRTC) to provide a seamless real-time communication experience.

## 🏛️ Architecture Overview

The Avina stack consists of several integrated components:

*   **Element Web**: The primary Matrix web client.
*   **Element Call**: A specialized, React-based application for multi-party video/audio calls using MatrixRTC.
*   **Matrix Authentication Service (MAS)**: A native OIDC provider that handles all user authentication, delegating to an upstream SSO provider (Keycloak).
*   **LiveKit**: A WebRTC SFU providing high-quality audio and video via MatrixRTC.
*   **Coturn**: A STUN/TURN relay to ensure media connectivity across restrictive networks.
*   **HAProxy**: The sole HTTP/S reverse proxy managing traffic between components.
*   **Cloudflared**: Creates a secure tunnel to the Cloudflare edge, exposing services without opening port 80/443.

## 🔒 Federated Posture (Private Federation)

Avina implements a **least-privilege federation model**. By default, it only federates with its own domain and a specific set of trusted partners.

*   **Whitelist Enforcement**: Only domains listed in the `federation_domain_whitelist` can exchange messages with this homeserver.
*   **Safety**: Your own `matrixDomain` is automatically included to ensure internal lookups and signature verification function correctly.
*   **Adding Partners**: To add a new federated server, add its domain to the `federatedDomains` list in `hosts/avina/default.nix`.

## 🔐 Security & Secret Management

Avina follows a "Zero Secrets in Nix Store" policy. No passwords, API keys, or tokens are ever stored in the Nix configuration or the globally-readable `/nix/store`.

### 1. Runtime Secrets (`/run/secrets`)
All sensitive data is provisioned manually by the operator into `/run/secrets/`. The NixOS modules reference these file paths at runtime.

| Secret Path | Purpose |
| :--- | :--- |
| `/run/secrets/synapse-secrets.yaml` | Master keys for Synapse (Macaroon, TURN, OIDC) |
| `/run/secrets/mas-config.yaml` | Full configuration for MAS, including DB and SSO secrets |
| `/run/secrets/cloudflared-creds.json` | Credentials for the Cloudflare Tunnel |
| `/run/secrets/synapse-email.yaml` | SMTP credentials for Mailgun notifications |
| `/run/secrets/vault-token.env` | Token for fetching TLS certificates from Vault |
| `/run/secrets/coturn-secret` | Shared secret for TURN authentication |

### 2. Automated TLS (Vault + Consul-Template)
Avina does not use ACME/Let's Encrypt locally. Instead, a `consul-template` daemon fetches certificates from a centralized **Vault** instance and renders them to `/run/certs/`. This ensures certificates are consistent across the fleet and never stored in the Nix store.

### 3. SSH Security
*   **Password Auth**: Disabled.
*   **Cert-Based Auth**: Enforced via a Trusted SSH CA. Only keys signed by the operator's CA can log in.
*   **Root Login**: Permitted only via certificates/keys (`prohibit-password`).

## 💿 Installation Guide (For New Users)

If you are new to NixOS, follow these steps to deploy Avina.

### Prerequisites
1.  A VM with at least **12GB RAM** and **4 CPU cores**.
2.  A 64-bit NixOS Installation ISO (Minimal recommended).
3.  Access to `/dev/sda` for installation.

### 1. Boot the Installer
Boot your VM from the NixOS ISO. Once at the prompt, set a temporary password for the `nixos` user to enable SSH if needed:
```bash
sudo passwd nixos
```

### 2. Clone the Configuration
Clone this repository to the live environment:
```bash
git clone https://github.com/mister2d/nix-nexus.git
cd nix-nexus
```

### 3. Provision Runtime Secrets
Before installing, you **must** provision the following secrets on the live system. This exhaustive block can be used as a template. Replace all `<PLACEHOLDER>` values with securely generated strings (e.g., `openssl rand -hex 32`).

```bash
# 1. Create the secrets directory
sudo mkdir -p /run/secrets
sudo chmod 700 /run/secrets

# 2. Synapse Secrets (YAML)
# Paths: macaroon_secret_key, form_secret, registration_shared_secret, 
# turn_shared_secret, and the MSC3861 client_secret (shared with MAS).
cat <<EOF | sudo tee /run/secrets/synapse-secrets.yaml > /dev/null
macaroon_secret_key: "<SECURE_TOKEN>"
form_secret: "<SECURE_TOKEN>"
registration_shared_secret: "<SECURE_TOKEN>"
turn_shared_secret: "<TURN_SHARED_SECRET>"
matrix_authentication_service:
  secret: "<MAS_TO_SYNAPSE_SHARED_SECRET>"
EOF

# 3. Synapse Email Secrets (YAML)
# smtp_pass: Your Mailgun SMTP password.
cat <<EOF | sudo tee /run/secrets/synapse-email.yaml > /dev/null
email:
  smtp_pass: "<MAILGUN_SMTP_PASSWORD>"
EOF

# 4. MAS Configuration (Full YAML)
# encryption: master key for OIDC sessions (Generate ONCE, never rotate)
# matrix.secret: matches the client_secret in synapse-secrets.yaml
cat <<EOF | sudo tee /run/secrets/mas-config.yaml > /dev/null
http:
  listeners:
    - name: web
      resources: [discovery, human, oauth, compat, graphql, assets]
      binds: [{ host: "127.0.0.1", port: 8181 }]
database:
  host: "/run/postgresql"
  database: "matrix-authentication-service"
  username: "matrix-authentication-service"
secrets:
  encryption: "<64_CHAR_HEX_ENCRYPTION_KEY>"
upstream_oauth2:
  providers:
    - id: keycloak
      issuer: "https://SSO_DOMAIN/realms/homelab"
      client_id: "mas"
      client_secret: "<KEYCLOAK_CLIENT_SECRET>"
matrix:
  kind: synapse
  homeserver: "MATRIX_DOMAIN"
  secret: "<MAS_TO_SYNAPSE_SHARED_SECRET>"
  endpoint: "http://127.0.0.1:8008"
EOF

# 4. Cloudflared Credentials (JSON)
# Obtain this from 'cloudflared tunnel create'
cat <<EOF | sudo tee /run/secrets/cloudflared-creds.json > /dev/null
{
  "AccountTag": "<ACCOUNT_ID>",
  "TunnelID": "<TUNNEL_ID>",
  "TunnelName": "avina-tunnel",
  "TunnelSecret": "<TUNNEL_SECRET>"
}
EOF

# 5. Vault Token for TLS (Env file)
# Used by consul-template to fetch certs from Vault KV-v2
echo "VAULT_TOKEN=<VAULT_TOKEN_WITH_KV_READ_POLICY>" | sudo tee /run/secrets/vault-token.env > /dev/null

# 6. Coturn Shared Secret (Plaintext)
# Used directly by Coturn and passed to LiveKit via environment
echo "<TURN_SHARED_SECRET>" | sudo tee /run/secrets/coturn-secret > /dev/null

# 7. LiveKit TURN Environment (Env file)
# Bridges the Coturn secret to the LiveKit service
echo "LIVEKIT_TURN_SHARED_SECRET=<TURN_SHARED_SECRET>" | sudo tee /run/secrets/coturn-secret-env > /dev/null

# 8. Set final permissions
sudo chmod 600 /run/secrets/*
```

### 4. Run the Install Script
The `install.sh` script handles partitioning (via Disko), ZFS setup, and system building. It is optimized for the VM's 12GB RAM to prevent Out-of-Memory (OOM) crashes.

```bash
sudo ./hosts/avina/install.sh
```

The script performs a "two-step" build:
1.  It builds the system directly onto the disk (`/mnt`) to save RAM.
2.  It registers the built packages so the installer can find them.
3.  It installs the bootloader and finishes the configuration.

### 5. Reboot
Once the script finishes successfully, reboot the VM:
```bash
sudo reboot
```

## 📈 Observability & Traceability

Avina is configured to leverage Cloudflare's edge headers for deep visibility into incoming traffic.

### 1. HAProxy Logging
HAProxy captures the following Cloudflare-specific metadata in its logs:
*   **`CF-Ray`**: Unique request ID for tracing through the Cloudflare network.
*   **`CF-Connecting-IP`**: The real IP of the client.
*   **`CF-IPCountry`**: The country code associated with the client IP.

The custom log format allows for easy parsing by external tools while providing immediate security awareness in the journal:
```
# Example log entry
haproxy[...]: 127.0.0.1:54321 [...] matrix_ingress mas_backend/mas ... "GET /auth HTTP/1.1" 8hf73js92lkf0 203.0.113.45 US
```

### 2. Backend Awareness
Both **Synapse** and **MAS** are configured to trust the proxy headers passed by HAProxy.
*   **Synapse**: Uses `trusted_proxies = ["127.0.0.1"]` to correctly resolve the client IP from the `X-Forwarded-For` header.
*   **Traceability**: HAProxy explicitly injects `X-Cloudflare-Ray` and `X-Cloudflare-Country` into backend requests, enabling application-level logging of the edge metadata.

## 📊 Persistence & Backups (ZFS)

Avina uses dedicated ZFS datasets for persistent data, allowing for atomic snapshots and efficient "data shipping" (backups).

*   `/var/lib/postgresql`: Database state.
*   `/var/lib/matrix-synapse`: Media uploads and Synapse state.
*   `/var/lib/matrix-authentication-service`: OIDC session data.
*   `/run/element-call`: Runtime directory for Element Call (static assets + config).

You can create a backup snapshot with:
```bash
zfs snapshot avina/postgresql@backup-$(date +%Y-%m-%d)
```

## 🛠️ Maintenance

To update the system after deployment:
1.  Modify the configuration in this repo.
2.  Run: `sudo nixos-rebuild switch --flake .#avina`
