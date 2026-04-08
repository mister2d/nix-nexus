# Nix-Nexus: Dendritic NixOS Infrastructure Harness

Nix-Nexus is a modular, dendritic NixOS configuration framework designed for high-performance workstations, servers, and portable user environments. It follows a pure, aspect-oriented architecture to separate hardware quirks, system policies, and functional software suites across a diverse fleet of nodes.

## 📋 Table of Contents
- [Architecture Overview](#-architecture-overview)
- [Fleet Composition](#-fleet-composition)
- [Directory Structure](#-directory-structure)
- [Matrix 2.0 Identity](#-matrix-20-identity)
- [Getting Started](#-getting-started)
- [Development Workflow](#-development-workflow)

---

## 🏛️ Architecture Overview
The configuration follows a **Dendritic Aspect-Oriented DAG** to ensure deterministic and scalable orchestration:

1.  **Aspects (`den.aspects`)**: Granular, reusable building blocks (Matrix, Sway, ZFS, Networking) defined in modular Nix files.
2.  **Provides (`den.provides`)**: Abstract interfaces (Hostname, StateVersion) that allow aspects to resolve dependencies.
3.  **Hosts (`den.hosts`)**: The fleet control plane, where host identities are mapped to a set of included aspects and site-specific overrides.

## 🚢 Fleet Composition
Nix-Nexus manages a diverse set of nodes via `modules/hosts.nix`:

*   **avina**: Sovereign Matrix 2.0 server (Proxmox LXC / x86_64).
*   **petunia**: Primary home server and storage node (NixOS / x86_64 / Ryzen).
*   **sweet16**: Mobile workstation — ThinkPad Z16 Gen 1 (NixOS / x86_64 / AMD OLED).

## 📁 Directory Structure
Legacy directories like `./hosts/` and `./profiles/` have been deprecated in favor of a unified module-based hierarchy.

```text
.
├── flake.nix               # Entry point; imports fleet via import-tree
├── modules/                # ALL configuration logic lives here
│   ├── hosts.nix           # Federated Fleet Registry (Control Plane)
│   ├── base.nix            # Foundation (HM, StateVersion, Timezone)
│   ├── matrix.nix          # Matrix 2.0 Gateway Aspect
│   ├── _matrix/            # Internal Matrix service modules (Synapse, MAS, etc.)
│   ├── _hw/                # Hardware-specific artifacts (Disko, configurations)
│   ├── _programs/          # Custom scripts and shell utilities
│   └── _user/              # Home Manager foundations (Shell, Neovim)
└── docs/                   # Deep-dive technical guides
```

---

## 💬 Matrix 2.0 Identity
The **avina** host runs a state-of-the-art, OIDC-native Matrix 2.0 stack. All configuration is managed via the `matrix` option set:

*   **OIDC native**: Delegates auth to Keycloak via MAS.
*   **MatrixRTC group calls**: Powered by a self-hosted LiveKit SFU.
*   **Standardized options**: Configure your domain and federated peers in one place.

---

## 🚀 Getting Started
To apply the configuration to any host in the fleet:
```bash
nixos-rebuild switch --flake .#<hostname>
```

To validate the entire fleet before deployment:
```bash
nix flake check
```

---

## 🛡️ Security & Secrets
Secrets are managed out-of-band or via the `vault-secrets` aspect. The infrastructure expects:
- `/run/secrets/synapse-secrets.yaml`
- `/run/secrets/vault-token.env` (for OIDC/MAS/TLS rendering)

Enjoy your reproducible, structured environment.
