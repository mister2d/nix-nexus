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
The configuration follows a dendritic (self-registering) flake architecture built on **flake-parts** and **import-tree**:

- Every `.nix` file in `modules/`, `hosts/`, and `profiles/` is a flake-parts module fragment that registers itself into `flake.modules.nixos` or `flake.modules.homeManager` under a kebab-cased name.
- `flake.nix` contains no per-file wiring — `import-tree` auto-discovers all fragments at evaluation time.
- Host assembly files in `modules/flake/` compose named modules by reference (`nixosModules.core-security`, `homeManagerModules.user-neovim-home`, etc.), producing a single point of truth for what each machine includes.

Concerns are separated across three tiers:

1. **Core** — foundational policies (timezone, ZFS, security, networking) applied globally via `modules/core/`.
2. **Profiles** — hardware-agnostic functional suites (`profiles/server`, `profiles/workstation`, `profiles/desktop`).
3. **Modules** — granular, opt-in aspects (`modules/hardware/`, `modules/services/`, `modules/user/`) composed by each host.

## 🚢 Fleet Composition

| Host | Role | OS | Arch |
|------|------|----|------|
| **avina** | Matrix 2.0 server (Proxmox LXC) | NixOS | x86_64 |
| **hermes** | LLM/MCP gateway (Proxmox LXC) | NixOS | x86_64 |
| **petunia** | AI/ML workstation & home server | NixOS | x86_64 |
| **sweet16** | Mobile workstation — ThinkPad Z16 Gen 1 | NixOS | x86_64 |
| **dualie** | Standalone dev environment | Debian Trixie (standalone HM) | x86_64 |
| **forge** | Standalone build node | Linux (standalone HM) | x86_64 |
| **rk3588** | SBC edge node — Rock 5 | Armbian (standalone HM) | aarch64 |

## 📁 Directory Structure
```text
.
├── flake.nix               # Composable import-tree builder (addPath over modules/hosts/profiles)
├── flake.lock
├── lib/                    # Non-module helpers (derivations, pure data)
│   ├── custom-scripts.nix  # Battery-alert, llm-init, etc.
│   ├── openclaude.nix      # Claude npm package derivation
│   └── avina/site-config.nix  # Avina domain constants
├── modules/
│   ├── flake/              # Host assembly files and flake output wiring
│   ├── core/               # System foundations (security, networking, ZFS)
│   ├── hardware/           # GPU, kernel, and platform aspects
│   ├── desktop/            # Hyprland, Noctalia, Wayland, and theme
│   ├── programs/           # Dev toolchains, scripts, package sets
│   ├── services/matrix/    # Matrix 2.0 stack (Synapse, MAS, LiveKit, HAProxy)
│   └── user/               # Home Manager aspects (shell, editor, terminal)
├── hosts/
│   ├── avina/              # Matrix 2.0 stack (LXC)
│   ├── hermes/             # LLM/MCP gateway (LXC)
│   ├── petunia/            # AI/ML workstation & home server
│   ├── sweet16/            # Mobile workstation (ThinkPad Z16)
│   ├── dualie/             # Standalone HM — Debian x86_64
│   ├── forge/              # Standalone HM — Linux x86_64
│   └── rk3588/             # Standalone HM — Armbian aarch64
├── profiles/               # Functional suites (server, workstation, desktop)
└── docs/                   # Deep-dive technical guides
```

---

## 💬 Matrix 2.0 & Collaboration
The **avina** host runs a state-of-the-art, OIDC-native Matrix 2.0 stack. This is the project's primary communications hub, featuring:

*   **OIDC Auth**: Fully delegated to Keycloak via MAS (Matrix Authentication Service).
*   **Native Calls**: MatrixRTC group calls powered by a self-hosted LiveKit SFU.
*   **Hybrid Ingress**: Dual-path signaling (Cloudflare Tunnel + Split-Horizon DNS) for maximum security and local performance.
*   **Direct Media**: WebRTC media bypasses the Cloudflare Tunnel entirely. LAN clients connect via direct host candidates; WAN clients use TURN relay via NAT-forwarded ports.

---

## 🚀 Getting Started
### NixOS Hosts
```bash
nixos-rebuild switch --flake .#sweet16
```

### Standalone Home Manager (Non-NixOS)
```bash
nix run home-manager/release-26.05 -- switch --flake .#groot@dualie -b bak
```

---

## 🛠️ Development Workflow

**New here? Start with the [Development Workflow guide](./docs/workflow.md)** —
it walks through the whole loop (find → edit → lint → validate → sign off →
deploy) and assumes no Nix knowledge.

### Standardized Environment
- **Activate:** `direnv allow`, or `nix develop --impure` (installs git hooks
  automatically). `--impure` is required — see the workflow guide.
- **Validate:** `.agents/scripts/preflight.sh <changed files>` (lint +
  `nix flake check --impure`).

### Isolated AI/LLM Projects
While the global environment is managed by Nix-Nexus, project-level AI toolchains utilize the **`llm-init`** script to bridge host GPU drivers to isolated Nix shells.
```bash
# Inside a project directory
llm-init
direnv allow
```

---

## 📚 Technical Documentation

### Architecture & Contributing
- [**Development Workflow**](./docs/workflow.md): Start here. The day-to-day loop — entering the shell, making a change, linting, checking blast radius, signing off, deploying, and what to do when something breaks.
- [**Architecture Guide**](./docs/architecture.md): How the dendritic pattern works — registries, fragments, host assembly, naming conventions.
- [**Cookbook**](./docs/cookbook.md): Step-by-step recipes for adding modules, users, application stacks, and new hosts.

### System Guides
- [**Upgrading**](./docs/upgrading.md): Routine updates, major release upgrades, rollback, and automatic upgrades — flake-native workflow.
- [**Matrix Reference**](./hosts/avina/PROTOCOL_REFERENCE.md): Specifications for the Matrix 2.0 stack and hybrid ingress architecture.
- [**Hardware Guide**](./docs/hardware.md): OLED optimizations, AMD P-State, and hybrid GPU management.
- [**CachyOS Kernel**](./docs/cachyos-kernel.md): CachyOS kernel setup, ZFS integration, and BBR3 tuning.
- [**Package Inventory**](./docs/packages.md): Pinned DevOps tool versions.
- [**Storage Management**](./docs/storage.md): CephFS mounting and ZFS dataset strategies.
- [**Terminal & Multiplexing**](./docs/terminal.md): Kitty/Tmux configuration and Bash aliases.
- [**Standalone Migration**](./docs/non-nixos.md): Moving dotfiles to Nix on non-NixOS hosts.
- [**Devenv 2.0 Workflows**](./docs/devenv.md): Declarative development environments replacing Docker Compose.
- [**Permafrost Host Module**](./docs/permafrost-host.md): The microvm bridge, NAT, kvm policy, and store settings behind the permafrost sandbox on sweet16.
- [**Hermes**](./docs/hermes.md): The AI agent gateway LXC host — hermes-agent, Matrix connection, Petunia-backed LLM.
- [**Secrets Management**](./docs/secrets.md): sops-nix, secretspec, and Vault layering, and TPM2 posture per host.
- [**Petunia**](./docs/petunia.md): Host-specific operations — TPM2 auto-unlock, dual GPU, rebuild procedure.
- [**Petunia Inference SBOM**](./docs/petunia-sbom.md): ROCm, HIP, Vulkan, and Mesa version inventory for the inference stack.

---
Enjoy your reproducible, structured environment.
