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

## Connectivity and Security

This framework prioritizes security and repository portability:
-   **SSIDs**: Network identifiers are managed via declarative profiles but are not hardcoded with secrets to remain Git-safe.
-   **Passwords**: NetworkManager persists credentials securely in the system keyfile or user keyring. They are never stored in the Nix store.

## Hardware Support

For detailed technical information regarding optimizations for specific hardware (such as the ThinkPad Z16's OLED panel and hybrid graphics), refer to the [HARDWARE-GUIDE.md](./HARDWARE-GUIDE.md).

Enjoy your reproducible, structured NixOS environment.
