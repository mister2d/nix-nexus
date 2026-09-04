# Environment Package Inventory

This document lists the software packages `nix-nexus` manages. It states each package's use case and role in the environment.

## Core Development & DevOps Tools
These tools use pinned versions. This keeps deployments fully reproducible.

| Package | Version | Description | Use Case |
|:---:|:---:|:--- |:--- |
| **Nomad** | 1.10.5 | HashiCorp workload orchestrator. | Managing containerized and non-containerized cluster workloads. |
| **Vault** | 1.21.1 | Identity-based secrets management. | Securely storing and accessing API keys, passwords, and certificates. |
| **Consul** | 1.22.1 | Service networking platform. | Service discovery, configuration, and segmentation. |
| **Terraform** | 1.14.5 | Infrastructure as Code (IaC) tool. | Declarative provisioning of cloud and on-prem resources. |
| **Talosctl** | 1.11.5 | CLI for Talos Linux. | Management and maintenance of Talos-based Kubernetes clusters. |
| **Helm** | 3.19.1 | Package manager for Kubernetes. | Managing complex Kubernetes applications via charts. |
| **Omnictl** | 1.3.4 | CLI for Sidero Omni. | Provisioning and managing bare-metal Kubernetes infrastructure. |
| **TFLint** | 0.59.1 | Terraform linter. | Detecting errors and enforcing best practices in HCL code. |
| **Freelens** | 1.6.1 | Kubernetes IDE (Lens). | Graphical interface for real-time cluster monitoring and management. |
| **Kubelogin-OIDC** | 1.34.2 | kubectl credential plugin. | OIDC authentication for Kubernetes clusters. |
| **Kubectl-Rook-Ceph** | 0.9.4 | kubectl plugin for Rook. | Direct management of Rook-Ceph storage clusters from the CLI. |
| **Kubectl-Doctor** | 0.3.1 | Cluster triage tool. | Rapid scanning and debugging of Kubernetes cluster health. |
| **Butane** | 0.25.1 | Ignition config transpiler. | Converting human-readable Butane configs to machine-readable Ignition. |
| **Envsubst** | 1.4.3 | Environment variable substitution. | Templating configuration files with dynamic environment data. |

## System Integration & Storage
| Package | Version | Description | Use Case |
|:---:|:---:|:--- |:--- |
| **Ceph-Client** | 19.2.3 | Native Ceph storage client. | Enabling the host to mount and interact with Ceph storage clusters. |
| **IPMITool** | Unstable | IPMI management utility. | Out-of-band management of server hardware. |

## Environment & Productivity
| Package | Description | Use Case |
|:---:|:--- |:--- |
| **Google Chrome** | Enterprise-grade web browser. | Primary web interface and web application development. |
| **Tmux** | Terminal multiplexer. | High-performance session management and pane splitting. |
| **Kitty** | GPU-accelerated terminal. | Fast, feature-rich terminal with ligatures and Nerd Font. |
| **Bash** | Standard UNIX shell. | Custom prompt, git integration, and HashiCorp completions. |
| **Librewolf** | Privacy-focused browser. | Secure web browsing with telemetry disabled. |
| **Meld** | Visual diff and merge tool. | Comparing files and directories; resolving git conflicts. |
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
Some packages come from a specific repository, for example `opencode` or `gemini-cli`. Update these in isolation. You do not touch the rest of the system.
*   **Target:** `inputs.llm-agents`
*   **Command:** `nix flake update llm-agents`

#### Scenario B: The package is part of the standard system (nixpkgs)
Some packages come from the primary NixOS repository, for example `tmux`, `git`, or `bash`. Update these by bumping the entire `nixpkgs` input. You cannot update these packages alone.
*   **Target:** `inputs.nixpkgs`
*   **Command:** `nix flake update nixpkgs`

#### Scenario C: Updating a Hard-Pinned Version
Some packages are hard pinned, for example `nomad` and `terraform`. A hard-pinned input points to one fixed commit. It never moves on its own. Update it by changing the commit hash in `flake.nix` by hand.
1.  Find the new hash on [NixHub.io](https://www.nixhub.io).
2.  Update `flake.nix`:
    ```nix
    pkgs-nomad.url = "github:nixos/nixpkgs/<NEW_COMMIT_HASH>";
    ```
3.  Run: `nix flake update pkgs-nomad`

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
