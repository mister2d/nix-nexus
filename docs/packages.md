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
**Used for:** Servers like `petunia` and workstations requiring specific driver/CUDA compatibility.

#### The Golden Rule of Pinning:
*   **If it's in the `nix-env` list:** You **DO NOT** need hashes. Simply point your config to the attribute (e.g., `.beta` or `.legacy_535`).
*   **If it's NOT in the list:** You **DO** need hashes and must use the `mkDriver` override.

#### A. NVIDIA Driver Discovery (No Hashes Required)
To see available driver branches already packaged in your current Nixpkgs channel:
```bash
nix-env -f '<nixpkgs>' -qaP -A linuxPackages.nvidiaPackages
```
*   **`.stable`**: The current production driver (Default).
*   **`.beta`**: Latest features/Vulkan extensions.
*   **`.legacy_470 / .legacy_535`**: Required for older hardware.
*   **`.dc`**: Data Center/Tesla optimized drivers.

**Pinning a Branch:**
In your hardware module (e.g., `modules/hardware/petunia/nvidia.nix`):
```nix
hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.beta;
```

#### B. CUDA Toolkit Discovery
CUDA is managed via the `cudaPackages` scope. To see available toolkit versions:
```bash
nix eval --json nixpkgs#cudaPackages --apply "builtins.attrNames" | jq -r '.[] | select(test("^cudaPackages_[0-9]"))'
```
This will return specific versioned sets like `cudaPackages_11`, `cudaPackages_12_2`, etc.

**Pinning a CUDA Version:**
When defining a dev shell or service that requires a specific CUDA version:
```nix
# Example: Use CUDA 12.2 specifically
let
  pkgs-cuda = pkgs.cudaPackages_12_2;
in {
  environment.systemPackages = [
    pkgs-cuda.cudatoolkit
    pkgs-cuda.cudnn
  ];
}
```

#### C. Manual Overrides (mkDriver)
Use this **only** if the specific version you need is missing from the `nix-env` list above.

**The "Lazy Hash" Workflow:**
You do not need to hunt for hashes on the internet. Nix can discover them for you:

1.  **Set Fake Hashes:** Populate all hash fields in `mkDriver` with `lib.fakeSha256`.
2.  **Satisfy Architectures:** Use `lib.fakeSha256` for `sha256_aarch64` even if you're on x86_64. Nix won't download the ARM version unless you're building on ARM, so the fake hash will never "fail."
3.  **Build:** Run `nixos-rebuild build`.
4.  **Extract the "Got" Hash:** The build will fail with a "hash mismatch" error.
    *   **`specified`**: The fake hash you put in.
    *   **`got`**: The **real** hash Nix found at the URL.
5.  **Iterate:** Copy the `got` hash into your config and rebuild. Repeat this for each component (driver, settings, open-source module) as they fail one by one.

**Example Configuration:**
```nix
hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
  version = "555.58.02";
  
  # Nix will tell you the correct hashes after the first failed build attempt
  sha256_64bit = "sha256-ActualHashFromBuildError...";
  sha256_aarch64 = "sha256-ActualHashOrFakeIfNeverBuilt..."; 
  openSha256 = "sha256-ActualHashFromBuildError...";
  settingsSha256 = "sha256-ActualHashFromBuildError...";
  persistencedSha256 = "sha256-ActualHashFromBuildError...";
};
```

**Common Questions:**
*   **"Do I have to set them all?"** Yes. The `mkDriver` function expects a complete set of attributes to evaluate.
*   **"I don't have aarch64!"** That's fine. Providing a hash for `aarch64` satisfies the Nix evaluator's requirement for the argument; it doesn't mean Nix will try to download or build the ARM version unless you are actually on an ARM machine. You can safely use the `lib.fakeSha256` or the actual ARM hash from the error log.

**Discovery & Verification:**
*   **Current Version:** `nix eval --raw .#nixosConfigurations.<host>.config.hardware.nvidia.package.version`
*   **Verify CUDA:** `nix eval --raw .#nixosConfigurations.<host>.pkgs.cudaPackages.cuda_nvcc.version`

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
