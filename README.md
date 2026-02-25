# Nix-Nexus: A Structured NixOS Configuration Framework

Nix-Nexus is a modular, branching configuration framework for NixOS designed for portability, scalability, and ease of management. It separates system-wide logic, functional suites, and machine-specific hardware details into distinct layers.

## Architectural Overview

The configuration follows a three-tier hierarchy to ensure concerns are properly separated:

1.  **Core (Global)**: Settings that apply to every machine in the fleet, such as timezones, global security policies, and foundational system modules.
    -   Location: `profiles/core/`
2.  **Profiles (Suites)**: Hardware-agnostic functional bundles of software and configuration (e.g., `profiles/desktop` for GUI environments or `profiles/development` for toolchains).
    -   Location: `profiles/`
3.  **Hosts**: Machine-specific configurations where physical hardware is defined and specific functional profiles are enabled.
    -   Location: `hosts/`

## Directory Structure

```text
.
├── flake.nix               # Project entry point and dependency management
├── hosts/                  # Machine-specific configurations
│   └── z16/                # ThinkPad Z16 Gen 1 definition
├── profiles/               # Functional suites and logical groupings
│   ├── core/               # Global system settings
│   ├── desktop/            # Desktop environment and UI components
│   ├── development/        # Development tools and scripts
│   └── hardware/           # Hardware-specific profile entry points
├── modules/                # Reusable component building blocks
│   ├── core/               # Low-level system modules (Boot, ZFS, Users)
│   ├── hardware/           
│   │   └── thinkpad-z16/   # Drivers and quirks for the Z16
│   ├── desktop/            # UI modules (Sway, Waybar, etc.)
│   ├── programs/           # Application-specific configurations
│   └── user/               
│       └── home.nix        # Home Manager user environment
└── HARDWARE-GUIDE.md       # Technical hardware reference
```

## Getting Started

### Applying Configuration
To apply the configuration to a local machine, use the following command (substituting `#sweet16` for your specific host):
```bash
sudo nixos-rebuild switch --flake .#sweet16
```

### Testing Changes
To evaluate a configuration without committing it to the boot menu:
```bash
sudo nixos-rebuild test --flake .#sweet16
```

### Rollbacks
NixOS retains previous generations. If a change causes issues, select an older generation at boot or run:
```bash
sudo nixos-rebuild switch --rollback
```

## Development Workflow

### Standardized Environment (DevShell)
The project includes a declarative development environment that automatically manages toolchains and git hooks. Entering the environment ensures all contributors use consistent formatting and linting standards.

1. **Activate Environment:** `nix develop` (installs git hooks automatically)
2. **Manual Validation:** `nix flake check` (runs all lints, formatters, and builds)
3. **Manual Hook Run:** `pre-commit run --all-files`

### Isolated Project Environments (Devbox)
While the `nix-nexus` framework defines the system-wide architecture, project-specific toolchains are managed using `devbox`. This keeps the global Nix store lean while providing isolated, reproducible environments for complex or bleeding-edge software (e.g., AI toolchains like `llama-cpp-vulkan`).

1. **Initialize Project:** `devbox init`
2. **Manage Dependencies:** `devbox add <package>@latest`
3. **Execute:** `devbox shell` (or use `direnv` for automatic loading)

## Terminal & Workflow

The system utilizes **Alacritty** paired with **Tmux** for a high-performance, OLED-optimized terminal environment.

### Tmux for Screen Users
The Tmux configuration is designed to be approachable for long-time `screen` users while leveraging modern features:

- **Prefix**: `Ctrl-a` (Matches traditional Screen).
- **Windows**:
  - `Ctrl-a` + `c`: Create new window.
  - `Shift-Left` / `Shift-Right`: Switch between windows.
- **Panes (Splits)**:
  - `Ctrl-a` + `|`: Split horizontally.
  - `Ctrl-a` + `-`: Split vertically.
  - `Ctrl-a` + `h/j/k/l`: Navigate panes (Vim-style).
- **General**:
  - **Mouse Support**: Enabled for scrolling and pane resizing.
  - **OLED Aesthetic**: True black background with Teal status indicators.

## Connectivity and Security

This framework prioritizes security and repository portability:
-   **SSIDs**: Network identifiers are managed via declarative profiles but are not hardcoded with secrets to remain Git-safe.
-   **Passwords**: NetworkManager persists credentials securely in the system keyfile or user keyring. They are never stored in the Nix store.

## Hardware Support

For detailed technical information regarding optimizations for specific hardware (such as the ThinkPad Z16's OLED panel and hybrid graphics), refer to the [HARDWARE-GUIDE.md](./HARDWARE-GUIDE.md).

## Software and Toolchains

A comprehensive inventory of managed packages, version-pinned DevOps tools, and their specific use cases can be found in the [PACKAGES.md](./PACKAGES.md) guide.

For information on managing remote storage and using the CephFS mount controller, refer to the [STORAGE.md](./STORAGE.md) documentation.

Enjoy your reproducible, structured NixOS environment.
