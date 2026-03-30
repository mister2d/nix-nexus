# Nix-Nexus: Structured Configuration Framework

Nix-Nexus is a modular, dendritic NixOS configuration framework designed for high-performance workstations, servers, and portable user environments. It follows a pure, aspect-oriented architecture to separate hardware quirks, system policies, and functional software suites across a diverse fleet of x86_64 and aarch64 nodes.

## 📋 Table of Contents
- [Architecture Overview](#-architecture-overview)
- [Fleet Composition](#-fleet-composition)
- [Directory Structure](#-directory-structure)
- [Matrix 2.0 & Collaboration](#-matrix-20--collaboration)
- [Getting Started](#-getting-started)
- [Development Workflow](#-development-workflow)
- [Technical Documentation](#-technical-documentation)

---

## 🏛️ Architecture Overview
The configuration follows a three-tier hierarchy to ensure concerns are properly separated:

1.  **Core (Global)**: Foundational settings (Timezones, ZFS, Security) that apply to every machine in the fleet.
2.  **Profiles (Suites)**: Hardware-agnostic functional bundles (Desktop environments, Server hardening, Dev toolchains).
3.  **Aspects (Modules)**: Reusable, granular building blocks (Matrix, Ceph, Virtualization) imported by hosts as needed.

## 🚢 Fleet Composition
Nix-Nexus manages a diverse set of nodes across multiple architectures:

*   **avina**: Public-facing Matrix 2.0 server (Proxmox LXC / x86_64).
*   **petunia**: Primary home server and storage node (NixOS / x86_64).
*   **sweet16**: Mobile workstation — ThinkPad Z16 Gen 1 (NixOS / x86_64).
*   **dualie**: Standalone development environment (Debian Trixie / x86_64).
*   **forge / rk3588**: Edge compute and SBC nodes (NixOS / aarch64).

## 📁 Directory Structure
```text
.
├── flake.nix               # Project entry point and dependency management
├── hosts/                  # Machine-specific entry points
│   ├── avina/              # Matrix 2.0 Stack (LXC)
│   ├── petunia/            # Home Server & Storage
│   └── sweet16/            # Workstation (ThinkPad Z16)
├── profiles/               # Functional suites (Server, Workstation, Desktop)
├── modules/                # Aspect-oriented modules
│   ├── core/               # System foundations (Security, Networking)
│   ├── hardware/           # Hardware-specific aspects (GPU, Ryzen)
│   ├── services/           # Matrix 2.0, Ceph, Vault
│   └── user/               # Home Manager aspects (Shell, Terminal, Neovim)
└── docs/                   # Deep-dive technical guides
```

---

## 💬 Matrix 2.0 & Collaboration
The **avina** host runs a state-of-the-art, OIDC-native Matrix 2.0 stack. This is the project's primary communications hub, featuring:

*   **OIDC Auth**: Fully delegated to Keycloak via MAS (Matrix Authentication Service).
*   **Native Calls**: MatrixRTC group calls powered by a self-hosted LiveKit SFU.
*   **Hybrid Ingress**: Dual-path signaling (Cloudflare Tunnel + Split-Horizon DNS) for maximum security and local performance.
*   **Direct Media**: Low-latency WebRTC paths that bypass proxies via direct WAN/LAN NAT.

---

## 🚀 Getting Started
### NixOS Hosts
To apply the configuration to a NixOS machine:
```bash
nixos-rebuild switch --flake .#sweet16
```

### Standalone Home Manager (Non-NixOS)
Manage user environments on existing distributions (Debian, macOS) or corporate laptops:
```bash
nix run home-manager/release-25.11 -- switch --flake .#groot@dualie -b bak
```

---

## 🛠️ Development Workflow
### Standardized Environment
- **Activate:** `nix develop` (installs git hooks automatically).
- **Validate:** `nix flake check` (evaluates tree-wide integrity).

### Isolated AI/LLM Projects
While the global environment is managed by Nix-Nexus, project-level AI toolchains utilize the **`llm-init`** script to bridge host GPU drivers to isolated Nix shells.
```bash
# Inside a project directory
llm-init
direnv allow
```

---

## 📚 Technical Documentation
- [**Matrix Reference**](./hosts/avina/PROTOCOL_REFERENCE.md): Detailed specifications for the Matrix 2.0 stack and hybrid ingress.
- [**Hardware Guide**](./docs/hardware.md): OLED optimizations, AMD P-State, and Hybrid GPU management.
- [**Package Inventory**](./docs/packages.md): Versions and use cases for pinned DevOps and Infrastructure tools.
- [**Storage Management**](./docs/storage.md): Centralized CephFS mounting and ZFS dataset strategies.
- [**Terminal & Multiplexing**](./docs/terminal.md): High-performance Kitty/Tmux configuration and Bash aliases.
- [**Standalone Migration**](./docs/non-nixos.md): Moving dotfiles to Nix securely on non-NixOS hosts.
- [**Devenv 2.0 Workflows**](./docs/devenv.md): Modern declarative development environments replacing Docker Compose.

---
Enjoy your reproducible, structured environment.
