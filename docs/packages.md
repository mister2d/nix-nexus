# Environment Package Inventory

This document lists the software packages `nix-nexus` manages. It states each package's use case and role in the environment.

## Core Development & DevOps Tools
nix-nexus no longer carries these. HashiCorp tools, Kubernetes and Talos CLIs,
AI coding agents, and the general development toolchain live in
the `nix-devshell` flake with their pinned versions. Enter a shell on demand
instead of installing them in the user environment. See
[devshell.md](./devshell.md) for the call recipes.

## System Integration & Storage
| Package | Version | Description | Use Case |
|:---:|:---:|:--- |:--- |
| **Ceph-Client** | 19.2.3 | Native Ceph storage client. | Enabling the host to mount and interact with Ceph storage clusters. |
| **IPMITool** | Unstable | IPMI management utility. | Out-of-band management of server hardware. |
| **Signalbackup-Tools** | Unstable | Signal backup utility. | Inspecting and exporting Signal backups. |

## Environment & Productivity
| Package | Description | Use Case |
|:---:|:--- |:--- |
| **Google Chrome** | Enterprise-grade web browser. | Primary web interface and web application development. |
| **Tmux** | Terminal multiplexer. | High-performance session management and pane splitting. |
| **Kitty** | GPU-accelerated terminal. | Fast, feature-rich terminal with ligatures and Nerd Font. |
| **Bash** | Standard UNIX shell. | Custom prompt, git integration, and HashiCorp completions. |
| **Librewolf** | Privacy-focused browser. | Secure web browsing with telemetry disabled. |
| **Television** | Fuzzy finder TUI. | Blazingly fast file and channel navigation (managed via Home Manager). |
| **Krita** | Professional painting/drawing tool. | Digital art and visual asset creation. |
| **MQTT Explorer** | MQTT client and visualization. | Monitoring and debugging MQTT message buses (Home Automation/IoT). |
| **Prusa Slicer** | 3D printing preparation tool. | Generating G-code for 3D printers. |
| **Super Slicer** | Advanced 3D slicing fork. | Granular control over complex 3D printing tasks. |
| **VLC** | Universal media player. | Playback of virtually any audio or video format. |
| **Signal Desktop** | Encrypted communication. | Secure messaging and collaboration. |
| **LibreOffice** | Productivity suite. | Document, spreadsheet, and presentation management. |

---

## Package Maintenance & Version Bumping

`nix-nexus` uses several pinning strategies. These strategies keep workstations and server nodes stable and reproducible. Update software and hardware drivers the Nix way for each pinning type.

### Channels vs. Flakes (The 2026 standard)
Never run `nix-channel --update` in this project. `flake.lock` locks all dependencies. A channel update does not affect the project. The flake environment stays isolated and reproducible.

### 1. Updating Specific Packages
The command depends on where `flake.nix` defines the package.

#### Scenario A: The package has its own Flake Input
Some packages come from a specific repository, for example `herdr`. Update these in isolation. You do not touch the rest of the system.
*   **Target:** `inputs.herdr`
*   **Command:** `nix flake update herdr`

#### Scenario B: The package is part of the standard system (nixpkgs)
Some packages come from the primary NixOS repository, for example `tmux`, `git`, or `bash`. Update these by bumping the entire `nixpkgs` input. You cannot update these packages alone.
*   **Target:** `inputs.nixpkgs`
*   **Command:** `nix flake update nixpkgs`

#### Scenario C: Updating a Hard-Pinned Version
Some packages are hard pinned, for example `vlc` and `ceph`. A hard-pinned input points to one fixed commit. It never moves on its own. Update it by changing the commit hash in `flake.nix` by hand.
1.  Find the new hash on [NixHub.io](https://www.nixhub.io).
2.  Update `flake.nix`:
    ```nix
    pkgs-vlc.url = "github:nixos/nixpkgs/<NEW_COMMIT_HASH>";
    ```
3.  Run: `nix flake update pkgs-vlc`

Pins for developer tooling (`nomad`, `terraform`, `vault`, and so on) are
maintained in the nix-devshell repository, not here.

### 2. Soft Pinning (Version Assertions)
**Used for:** The Matrix 2.0 stack (Synapse, MAS, LiveKit, Vault) in `modules/services/matrix/versions.nix`.
These packages follow the primary `nixpkgs` input. Assertions protect them and block accidental upgrades during a rolling system update.

**The Update Process:**
1.  **Update Global Nixpkgs:** Run `nix flake update nixpkgs`.
2.  **Trigger Assertion:** Build or evaluate the configuration, for example `nixos-rebuild dry-run --flake .#avina`. If nixpkgs updated a pinned package, the build fails with a "Matrix stack version drift" error.
3.  **Acknowledge & Bump:** Verify the new version is compatible. Then update the constant in `modules/services/matrix/versions.nix` to match the new version string.
4.  **Validate:** Re-run the evaluation. It should now pass.

### 3. Rolling Updates (Standard Packages)
**Used for:** System utilities, terminal tools, and productivity apps.
The standard `nixpkgs` and `nixpkgs-unstable` inputs manage these packages. They need no extra pinning logic.

**The Update Process:**
1.  Run `nix flake update`.
2.  Test for regressions across different hosts.
3.  Commit the updated `flake.lock`.

### Recommended Tools
*   **NixHub.io**: Search for package version history and commit hashes.
*   **nix-diff**: Compare two derivations to see what changed in an update.
*   **nix-tree**: View package dependency graphs to find why a specific version is pulled in.
