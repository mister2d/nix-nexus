# Environment Package Inventory

This document provides a comprehensive list of the software packages managed within the `nix-nexus` environment, including their specific use cases and roles within the ecosystem.

## Core Development & DevOps Tools
These tools are pinned to specific versions to ensure absolute reproducibility across deployments.

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

## Desktop Utilities (Sway/Wayland)
- **Wofi**: Application launcher and GPU selector backend.
- **Waybar**: Highly customizable status bar for Wayland compositors.
- **Kanshi**: Dynamic display profile manager for docking/undocking.
- **EasyEffects**: System-wide audio processing and equalization.
- **Grim/Slurp**: High-performance screenshot and region selection tools.
- **Clipman**: History-persistent clipboard manager.
- **Pamixer**: Command-line PulseAudio/PipeWire volume control.
- **Battery-travel-mode**: Helper script for ThinkPad Z16 to temporarily override battery charging thresholds for long trips.

---

## Package Maintenance & Hardware Pinning

To ensure system stability and reproducibility across workstations and server nodes, `nix-nexus` employs four distinct pinning strategies. Updating software and hardware drivers requires following the "Nix proper way" for each type.

### 1. Hard Pinning (Dedicated Flake Inputs)
**Used for:** Google Chrome, Nomad, Terraform, Talosctl, and other mission-critical DevOps tools.
These are pinned to specific `nixpkgs` commit hashes in `flake.nix` to guarantee the exact binary version regardless of global system updates.

**The Update Process:**
1.  **Identify Version:** Use [NixHub.io](https://www.nixhub.io) to find the `nixpkgs` commit hash containing your desired version.
2.  **Update Flake:** Locate the corresponding input in `flake.nix` (e.g., `pkgs-nomad`) and update the URL hash.
    ```nix
    pkgs-nomad.url = "github:nixos/nixpkgs/<NEW_COMMIT_HASH>";
    ```
3.  **Refresh Lockfile:** Run `nix flake update <input-name>` to synchronize `flake.lock`.
4.  **Validate:** Run `nix flake check` and verify the package version:
    ```bash
    nix eval --raw .#nixosConfigurations.<host>.pkgs.nomad.version
    ```
5.  **Document:** Update the version string in the tables above to match the new state.

### 2. Soft Pinning (Version Assertions)
**Used for:** The Matrix 2.0 stack (Synapse, MAS, LiveKit, Vault) in `modules/services/matrix/versions.nix`.
These packages follow the primary `nixpkgs` input but are protected by assertions to prevent "accidental" upgrades during a rolling system update.

**The Update Process:**
1.  **Update Global Nixpkgs:** Run `nix flake update nixpkgs`.
2.  **Trigger Assertion:** Attempt to build or evaluate the configuration (e.g., `nixos-rebuild dry-run --flake .#avina`). If a pinned package was updated in nixpkgs, the build will fail with a "Matrix stack version drift" error.
3.  **Acknowledge & Bump:** Verify the new version is compatible, then update the constant in `modules/services/matrix/versions.nix` to match the new version string.
4.  **Validate:** Re-run the evaluation; it should now pass.

### 3. Hardware-Level Pinning (NVIDIA & CUDA)
**Used for:** Servers like `petunia` and workstations with specific driver/CUDA requirements.
To pin a specific NVIDIA driver version not present in your current `nixpkgs` channel, use the `mkDriver` function.

**The Update Process:**
1.  **Define specific package:** In your hardware module (e.g., `modules/hardware/petunia/nvidia.nix`), override the package using `mkDriver`:
    ```nix
    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "555.58.02";
      sha256_64bit = "sha256-xctt4TPRlOJ6r5S54h5W6PT6/3Zy2R4ASNFPu8TSHKM=";
      sha256_aarch64 = "sha256-xctt4TPRlOJ6r5S54h5W6PT6/3Zy2R4ASNFPu8TSHKM=";
      openSha256 = "sha256-ZpuVZybW6CFN/gz9rx+UJvQ715FZnAOYfHn5jt5Z2C8=";
      settingsSha256 = "sha256-ZpuVZybW6CFN/gz9rx+UJvQ715FZnAOYfHn5jt5Z2C8=";
      persistencedSha256 = "sha256-ZpuVZybW6CFN/gz9rx+UJvQ715FZnAOYfHn5jt5Z2C8=";
    };
    ```
2.  **CUDA/Container Runtime:** To ensure CUDA tools match your driver, always reference `config.hardware.nvidia.package` when building container environments or custom systemd services like NVIDIA MPS (Multi-Process Service).

**Discovery & Verification:**
*   **Finding Versions:** Check the [NVIDIA Driver Downloads](https://www.nvidia.com/Download/index.aspx) page for the latest Linux 64-bit version numbers.
*   **Querying CUDA:** Use `nix search nixpkgs cudaPackages` to see which CUDA toolkit versions are available in your current channel (e.g., `cudaPackages_12_2`).
*   **Retrieving Hashes:** 
    1.  Set the hashes in `mkDriver` to `lib.fakeSha256`.
    2.  Run `nixos-rebuild build`. The build will fail and report the "actual" hash found at the NVIDIA download URL.
    3.  Alternatively, use `nix-prefetch-url` with the direct download URL:
        `nix-prefetch-url https://us.download.nvidia.com/XFree86/Linux-x86_64/<VERSION>/NVIDIA-Linux-x86_64-<VERSION>.run`
*   **Matching Drivers:** Ensure the `version` string in `mkDriver` exactly matches the NVIDIA release (e.g., `555.58.02`).

### 4. Rolling Updates (Standard Packages)
**Used for:** System utilities, terminal tools, and productivity apps.
These are managed via the standard `nixpkgs` and `nixpkgs-unstable` inputs without extra pinning logic.

**The Update Process:**
1.  Run `nix flake update`.
2.  Test for regressions across different hosts.
3.  Commit the updated `flake.lock`.

### Recommended Tools
*   **NixHub.io**: Search for package version history and commit hashes.
*   **nix-diff**: Compare two derivations to see exactly what changed in an update.
*   **nix-tree**: Visualize package dependency graphs to identify why a specific version is being pulled in.
