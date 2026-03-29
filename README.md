# Nix-Nexus: Dendritic Configuration Framework

Nix-Nexus is a modular, aspect-oriented NixOS configuration framework powered by the **Den framework (v0.13.0)**. It manages high-performance workstations, servers, and portable user environments through a unified, dendritic architecture.

## 📋 Table of Contents
- [Architecture Overview](#-architecture-overview)
- [Directory Structure](#-directory-structure)
- [Getting Started (NixOS)](#-getting-started-nixos)
- [Non-NixOS Environments (Standalone)](#-non-nixos-environments-standalone)
- [Development Workflow](#-development-workflow)
- [Technical Documentation](#-technical-documentation)

---

## 🏛️ Architecture Overview
Nix-Nexus follows a **Dendritic (Aspect-Oriented)** philosophy. Instead of separating configuration by location (hosts vs. profiles), we organize by **Feature Aspects**.

An **Aspect** is a single file in the `modules/` directory that owns all configuration for a specific feature (e.g., `sway.nix`, `matrix.nix`). Each aspect can define:
- **NixOS**: System-level packages and services.
- **Home Manager**: User-level dotfiles and environment settings.
- **Hardware**: Quirks and optimizations for specific machines.

The entire fleet is orchestrated from a single "Control Plane" in **`modules/hosts.nix`**, where hosts are declared by including their required aspects.

## 📁 Directory Structure
```text
.
├── flake.nix               # Minimal orchestrator and dependency management
├── modules/                # Unified Aspect Registry (The Heart of the System)
│   ├── hosts.nix           # Fleet Control Plane: Host & Home declarations
│   ├── base.nix            # Foundational settings (Core)
│   ├── sway.nix            # Desktop Aspect (NixOS + Home Manager)
│   ├── matrix.nix          # Matrix 2.0 Aspect
│   ├── _hw/                # Machine-specific non-portable hardware configs
│   └── _matrix/            # Internal service modules for the Matrix stack
└── docs/                   # Deep-dive technical guides
    ├── den-architecture.md # Technical guide to the Dendritic Den model
    ├── hardware.md         # Hardware-specific quirks (OLED, GPU, P-State)
    ├── packages.md         # Pinned toolchains (Nomad, Vault, Terraform)
    └── non-nixos.md        # Standalone Home Manager on Debian/Work laptops
```

---

## 🚀 Getting Started (NixOS)
### Applying Configuration
To apply the configuration to a NixOS machine:
```bash
sudo nixos-rebuild switch --flake .#<hostname>
```
*Current hosts: `sweet16`, `petunia`, `avina`.*

### Testing & Rollbacks
- **Eval without boot entry:** `sudo nixos-rebuild test --flake .#<hostname>`
- **Instant recovery:** `sudo nixos-rebuild switch --rollback`

---

## 💻 Non-NixOS Environments (Standalone)
Nix-Nexus manages your user environment on existing distributions (Debian, Ubuntu) or locked-down corporate laptops without replacing the host OS.

1. **Bootstrap Nix:** Install the Nix daemon in multi-user mode.
2. **Apply Profile:** 
   ```bash
   nix run home-manager/release-25.11 -- switch --flake .#groot@<hostname> -b bak
   ```
   *Current homes: `groot@dualie`, `groot@forge`, `groot@rk3588`.*

3. **Learn More:** See the [Non-NixOS Guide](./docs/non-nixos.md).

---

## 🛠️ Development Workflow
### Standardized Environment
- **Activate:** `nix develop` (installs git hooks automatically).
- **Validate:** `nix flake check` (evaluates tree-wide integrity).

### Automated Discovery
Adding a new `.nix` file to `modules/` (not starting with `_`) automatically registers it as a Den Aspect. No manual wiring in `flake.nix` is required.

---

## 📚 Technical Documentation
- [**Den Architecture**](./docs/den-architecture.md): Deep dive into the aspect-oriented model and fleet orchestration.
- [**Hardware Guide**](./docs/hardware.md): OLED optimizations, AMD P-State, and Hybrid GPU management.
- [**Package Inventory**](./docs/packages.md): Versions and use cases for pinned DevOps and Infrastructure tools.
- [**Storage Management**](./docs/storage.md): Centralized CephFS mounting and ZFS dataset strategies.
- [**Terminal & Multiplexing**](./docs/terminal.md): High-performance Kitty/Tmux configuration and Bash aliases.
- [**Standalone Migration**](./docs/non-nixos.md): Moving your dotfiles to Nix securely on non-NixOS hosts.

---
Enjoy your reproducible, dendritic environment.
