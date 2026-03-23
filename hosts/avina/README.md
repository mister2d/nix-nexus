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

## 🔐 Security & Secret Management

Avina follows a **Zero Secrets in Nix Store** policy combined with an **Automated Bootstrap** model. 

### 1. The Security Hierarchy
To maintain a least-privilege posture, Avina uses three distinct levels of authentication:

| Level | Key Type | Purpose | Persistent? |
| :--- | :--- | :--- | :--- |
| **High** | **Admin Token** | Used locally to run `deploy-avina.sh`. | No |
| **Low** | **AppRole** | The host's permanent ID used to self-bootstrap at boot. | **Yes** |

### 2. The Bootstrap Model ("The Master Key")
Instead of manually provisioning dozens of secrets, Avina uses a single persistent "Master Key" to unlock the rest of its configuration from **Hashicorp Vault** at boot time.

*   **Persistent Secret**: A Vault **AppRole** (Role-ID and Secret-ID) is stored on a dedicated persistent ZFS dataset at `/var/lib/secrets/`. This is the only secret that survives a reboot.
*   **Vault Agent**: A sidecar service authenticates with Vault using the Master Key and maintains a short-lived access token in memory.
*   **Consul Template**: A rendering engine uses the token to fetch Synapse keys, MAS configs, and TLS certificates from Vault, writing them directly to the memory-backed `/run/secrets/` directory.

## 💿 Installation Guide (Two-Stage UEFI)

Avina uses a two-stage deployment process to ensure a clean ZFS bootstrap followed by a secure, automated application deployment.

### Prerequisites
1.  A VM with **UEFI** enabled (OVMF).
2.  At least **12GB RAM** and **4 CPU cores**.
3.  A 64-bit NixOS Installation ISO.
4.  Access to a **Hashicorp Vault** instance.

---

### Stage 1: Minimal ZFS Bootstrap
This stage partitions your disk, sets up ZFS, and installs a minimal NixOS base.

1.  **Boot the ISO** and clone the repository:
    ```bash
    git clone https://github.com/mister2d/nix-nexus.git
    cd nix-nexus
    ```
2.  **Run the partitioner**:
    ```bash
    # This will wipe /dev/sda and create the ZFS pool 'avina'
    sudo nix run github:nix-community/disko -- --mode disko ./hosts/avina/disko.nix
    ```
3.  **Perform the base install**:
    ```bash
    # Installs the 'avina-bootstrap' profile to /mnt
    sudo nixos-install --flake .#avina-bootstrap
    ```
4.  **Reboot** into your new minimal system.

---

### Stage 2: Full Matrix 2.0 Deployment
Once the machine has rebooted into the base NixOS, you will use the unified deployment script to seed Vault and configure the Matrix stack.

1.  **Login** to the new system and enter the repository directory.
2.  **Run the deployment wrapper**:
    ```bash
    sudo ./hosts/avina/deploy-avina.sh
    ```
3.  **Interactive Workflow**:
    *   The script will prompt for your **Vault Address** and **Admin Token**.
    *   It will ensure the **AppRole** and **Policies** are created.
    *   It will interactively prompt you to seed the necessary Matrix secrets into Vault.
    *   It will provision the **Master Key** to `/var/lib/secrets`.
    *   Finally, it will trigger a `nixos-rebuild switch` to the full `avina` configuration.

---

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
