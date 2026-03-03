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
| **Librewolf** | Privacy-focused browser. | Secure web browsing with telemetry disabled. |
| **Meld** | Visual diff and merge tool. | Comparing files and directories; resolving git conflicts. |
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
