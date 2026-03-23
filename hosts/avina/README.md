# Avina: Matrix 2.0 Communications Server

Avina is a high-performance, secure, and fully public **Matrix 2.0** homeserver built on NixOS. It leverages modern Matrix standards (OIDC, MatrixRTC) to provide a seamless real-time communication experience.

## 🏛️ Architecture Overview

The Avina stack consists of several integrated components:

*   **Synapse**: The core Matrix homeserver (backend).
*   **Matrix Authentication Service (MAS)**: A native OIDC provider that handles all user authentication, delegating to an upstream SSO provider (Keycloak).
*   **Element Web**: The primary Matrix web client.
*   **Element Call**: A specialized, React-based application for multi-party video/audio calls using MatrixRTC.
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

Avina follows a **Zero Secrets in Nix Store** policy combined with an **Automated Bootstrap** model. 

### 1. The Security Hierarchy
To maintain a least-privilege posture, Avina uses three distinct levels of authentication:

| Level | Key Type | Purpose | Persistent? |
| :--- | :--- | :--- | :--- |
| **High** | **Admin Token** | Used locally to run `seed-vault.sh`. | No |
| **Med** | **Install Token** | Temporary lease used by `install.sh` to fetch secrets. | No |
| **Low** | **AppRole** | The host's permanent ID used to self-bootstrap at boot. | **Yes** |

### 2. The Bootstrap Model ("The Master Key")
Instead of manually provisioning dozens of secrets, Avina uses a single persistent "Master Key" to unlock the rest of its configuration from **HashiCorp Vault** at boot time.

*   **Persistent Secret**: A Vault **AppRole** (Role-ID and Secret-ID) is stored on a dedicated persistent ZFS dataset at `/var/lib/secrets/`. This is the only secret that survives a reboot.
*   **Vault Agent**: A sidecar service authenticates with Vault using the Master Key and maintains a short-lived access token in memory.
*   **Consul Template**: A rendering engine uses the token to fetch Synapse keys, MAS configs, and TLS certificates from Vault, writing them directly to the memory-backed `/run/secrets/` directory.

### 2. Secret Lifecycle & Persistence
*   **Memory-Backed (`tmpfs`)**: All operational secrets (Synapse keys, SMTP passes, OIDC secrets) live in RAM (`/run/secrets`). They are **wiped on every reboot** for maximum security.
*   **Self-Healing**: On boot, the system automatically authenticates to Vault and restores the `/run/secrets` directory. 
*   **Live Updates**: Changes made in the Vault UI/CLI are detected by the system within seconds. Services (HAProxy, Synapse, MAS) are automatically reloaded or restarted to apply the new secrets without a NixOS rebuild.

### 3. Automated TLS (Vault + Consul-Template)
Avina does not use local ACME clients. TLS certificates are managed centrally in Vault and pushed to the host via the same `consul-template` mechanism described above.

## 📈 Observability & Traceability

Avina is configured to leverage Cloudflare's edge headers for deep visibility into incoming traffic.

### 1. HAProxy Logging
HAProxy captures the following Cloudflare-specific metadata in its logs:
*   **`CF-Ray`**: Unique request ID for tracing through the Cloudflare network.
*   **`CF-Connecting-IP`**: The real IP of the client.
*   **`CF-IPCountry`**: The country code associated with the client IP.

### 2. Backend Awareness
Both **Synapse** and **MAS** are configured to trust the proxy headers passed by HAProxy.
*   **Synapse**: Uses `trusted_proxies = ["127.0.0.1"]` to correctly resolve the client IP from the `X-Forwarded-For` header.
*   **Traceability**: HAProxy explicitly injects `X-Cloudflare-Ray` and `X-Cloudflare-Country` into backend requests, enabling application-level logging of the edge metadata.

## 💿 Installation Guide

Deployment involves preparing your Vault infrastructure and then running the interactive installer on the target host.

### 1. Pre-Installation: Vault Setup
You must configure Vault to provide the host with its initial bootstrap credentials. A helper script is provided to automate this:

1.  **Environment**: Ensure you have the `vault` binary installed and are authenticated with administrative privileges.
2.  **Run Seeder**: Execute the seeding script from your local workstation:
    ```bash
    export VAULT_ADDR="https://your-vault-url"
    export VAULT_TOKEN="your-admin-token"
    ./hosts/avina/seed-vault.sh
    ```
3.  **Process**: The script will:
    *   Enable the **AppRole** authentication method.
    *   Create a **least-privilege policy** allowing the host to read only its required secrets.
    *   Interactively prompt you for Synapse, MAS, and Cloudflare credentials to seed the KV-v2 engine.
4.  **Note credentials**: At the end, the script will provide the command to obtain the **Role-ID** and **Secret-ID**. You will need these for the next step.

### 2. Boot the Installer
Boot the target VM from a standard NixOS Installation ISO. Once at the prompt, clone the configuration:
```bash
git clone https://github.com/mister2d/nix-nexus.git
cd nix-nexus
```

### 3. Run the Interactive Install Script
The `install.sh` script handles partitioning, ZFS setup, and automated secret bootstrap. It is optimized for the VM's 12GB RAM to prevent Out-of-Memory (OOM) failures.

```bash
sudo ./hosts/avina/install.sh
```

The script will guide you through the following steps:
1.  **Vault Authentication**: 
    *   **Vault URL**: The address of your Vault server.
    *   **Installation Token**: Provide the **renewable orphan token** generated in Step 1. This token is used *only* during installation to verify the stack and is never stored on the host.
2.  **Host Identity (AppRole)**: 
    *   **Role-ID & Secret-ID**: Provide the AppRole credentials generated in Step 1.
    *   **Persistence**: These are stored securely on the persistent `/var/lib/secrets` dataset. This is the "Master Key" the host uses to recover its own secrets after a reboot.
3.  **Validation**: The script uses the Installation Token to render all runtime secrets into `/run/secrets`. This confirms your Vault configuration is valid before any changes are made to the disk.
4.  **Two-Step Build**: Builds the system directly onto the disk (`/mnt`) to preserve RAM.
5.  **Final Confirmation**: Asks for a firm confirmation before the final unattended installation stage.

### 4. Reboot
Once the script finishes successfully, reboot the VM:
```bash
sudo reboot
```
The system will boot, authenticate to Vault using the stored Master Key, and start the entire Matrix 2.0 stack automatically.

## 📊 Persistence & Backups (ZFS)

Avina uses dedicated ZFS datasets for persistent data, allowing for atomic snapshots and efficient "data shipping" (backups).

*   `/var/lib/postgresql`: Database state.
*   `/var/lib/matrix-synapse`: Media uploads and Synapse state.
*   `/var/lib/matrix-authentication-service`: OIDC session data.
*   `/var/lib/secrets`: Persistent Vault bootstrap keys (The "Master Key").

## 🛠️ Maintenance

To update the system after deployment:
1.  Modify the configuration in this repo.
2.  Run: `sudo nixos-rebuild switch --flake .#avina`
