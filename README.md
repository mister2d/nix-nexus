# Nix-Nexus: Structured Configuration Framework

Nix-Nexus is a modular, dendritic NixOS configuration framework designed for high-performance workstations, servers, and portable user environments. It follows a layered architecture to separate hardware quirks, system policies, and functional software suites.

## 📋 Table of Contents
- [Architecture Overview](#-architecture-overview)
- [Directory Structure](#-directory-structure)
- [Getting Started (NixOS)](#-getting-started-nixos)
- [Non-NixOS Environments (Standalone)](#-non-nixos-environments-standalone)
- [Development Workflow](#-development-workflow)
- [Technical Documentation](#-technical-documentation)

---

## 🏛️ Architecture Overview
The configuration follows a three-tier hierarchy to ensure concerns are properly separated:

1.  **Core (Global)**: Foundational settings (Timezones, ZFS, Security) that apply to every machine in the fleet.
2.  **Profiles (Suites)**: Hardware-agnostic functional bundles (Desktop environments, Dev toolchains).
3.  **Hosts**: Machine-specific entry points where physical hardware is defined and profiles are selected.

## 📁 Directory Structure
```text
.
├── flake.nix               # Project entry point and dependency management
├── docs/                   # Deep-dive technical guides
├── hosts/                  # Machine-specific configurations
│   ├── z16/                # ThinkPad Z16 Gen 1 (Workstation)
│   └── dualie/             # Debian Trixie (Standalone Development)
├── profiles/               # Functional suites (Core, Desktop, Development)
├── modules/                # Reusable building blocks (Boot, Networking, Users)
└── docs/
    ├── hardware.md         # Hardware-specific quirks (OLED, GPU, P-State)
    ├── packages.md         # Pinned toolchains (Nomad, Vault, Terraform)
    ├── storage.md          # CephFS and ZFS mount management
    └── non-nixos.md        # Standalone Home Manager on Debian/Work laptops
```

---

## 🚀 Getting Started (NixOS)
### Applying Configuration
To apply the configuration to a NixOS machine:
```bash
sudo nixos-rebuild switch --flake .#sweet16
```

### Testing & Rollbacks
- **Eval without boot entry:** `sudo nixos-rebuild test --flake .#sweet16`
- **Instant recovery:** `sudo nixos-rebuild switch --rollback`

---

## 💻 Non-NixOS Environments (Standalone)
Nix-Nexus can manage your user environment on existing distributions (Debian, Ubuntu) or locked-down corporate laptops without replacing the host OS.

1. **Bootstrap Nix:** Install the Nix daemon in multi-user mode.
2. **Apply Profile:** 
   ```bash
   nix run home-manager/release-25.11 -- switch --flake .#groot@dualie -b bak
   ```
3. **Learn More:** See the [Non-NixOS Guide](./docs/non-nixos.md) for safe migration and GPU bridging.

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
- [**Hardware Guide**](./docs/hardware.md): OLED optimizations, AMD P-State, and Hybrid GPU management.
- [**Package Inventory**](./docs/packages.md): Versions and use cases for pinned DevOps and Infrastructure tools.
- [**Storage Management**](./docs/storage.md): Centralized CephFS mounting and ZFS dataset strategies.
- [**Standalone Migration**](./docs/non-nixos.md): Moving your dotfiles to Nix securely on non-NixOS hosts.

---
Enjoy your reproducible, structured environment.
