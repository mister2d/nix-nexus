# Nix-Nexus: A Dendritic NixOS Configuration

Welcome to Nix-Nexus! This project provides a clean, branching ("dendritic") configuration for NixOS, optimized for portability and ease of use.

## 🏗️ Architectural Overview

Following the **Dendritic Model**, the configuration is separated into three distinct layers of abstraction:

1.  **Core (Global)**: Settings that apply to *every* machine (Timezone, SSH keys, basic Nix settings).
    -   Location: `profiles/core/`
2.  **Profiles (Suites)**: Functional "bundles" of software and settings (e.g., `profiles/desktop`, `profiles/development`). These are hardware-agnostic.
    -   Location: `profiles/`
3.  **Hosts (The Dendritic Tip)**: Machine-specific configurations. This is where you define your specific hardware (e.g., ThinkPad Z16) and choose which functional profiles to enable.
    -   Location: `hosts/`

## 📁 Directory Structure

```text
.
├── flake.nix               # Project entry point
├── hosts/                  # Machine-specific configurations
│   └── z16/                # ThinkPad Z16 Gen 1
├── profiles/               # Functional suites (Suites)
│   ├── core/               # Global settings for all machines
│   ├── desktop/            # Sway, Wayland, Fonts, Themes
│   ├── development/        # Dev tools, scripts, Syncthing
│   └── hardware/           # Hardware-specific profile entries
├── modules/                # Individual functional components
│   ├── core/               # Boot, Networking, Security, Users, ZFS
│   ├── hardware/           
│   │   └── thinkpad-z16/   # Z16 Specific Drivers & Quirks
│   ├── desktop/            # UI components (Sway, Waybar, etc.)
│   ├── programs/           # Software packages
│   └── user/               
│       └── home.nix        # Home Manager (User Environment)
└── HARDWARE-GUIDE.md       # Hardware-specific optimizations (Z16)
```

## 🚀 Usage for Beginners

### 1. Applying Changes
If you edit your configuration, apply it with:
```bash
sudo nixos-rebuild switch --flake .#sweet16
```

### 2. Testing Changes
To test a configuration without making it permanent (it will disappear after a reboot):
```bash
sudo nixos-rebuild test --flake .#sweet16
```

### 3. Rolling Back
If something breaks, you can select an older version at the boot menu, or run:
```bash
sudo nixos-rebuild switch --rollback
```

## 🔐 Connectivity & SSID Strategy

This configuration is designed for security and Git-portability:
-   **SSIDs**: Not hardcoded in the Nix files to keep your configuration clean and portable.
-   **Connecting**: Use `nmtui` (terminal) or the network applet (tray icon) to connect to a new network.
-   **Persistence**: NetworkManager securely stores passwords in `/etc/NetworkManager/system-connections/` or your user's encrypted keyring. They are **never** stored in the world-readable Nix store.

## 🛠️ How to Add a New Machine

1.  Create a new folder in `hosts/` (e.g., `hosts/my-laptop/`).
2.  Add your `hardware-configuration.nix` (generated during install).
3.  Create a `default.nix` that imports the profiles you want:
    ```nix
    { config, pkgs, inputs, ... }:
    {
      imports = [
        ./hardware-configuration.nix
        ../../profiles/core
        ../../profiles/desktop
      ];
      networking.hostName = "my-laptop";
      networking.hostId = "generated-uuid";
    }
    ```
4.  Add the new host entry to `flake.nix` under `nixosConfigurations`.

## 💎 Hardware Optimizations

For details on how we optimized the **ThinkPad Z16 Gen 1** (OLED, AMD Hybrid Graphics, Power Management), please see [HARDWARE-GUIDE.md](./HARDWARE-GUIDE.md).

Enjoy your declarative, reproducible system! 🎉
