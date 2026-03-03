# ThinkPad Z16 Gen 1: Hardware-Specific Optimizations

This guide details the technical configurations and hardware optimizations applied to the ThinkPad Z16 Gen 1 (OLED model with hybrid AMD graphics). These settings are isolated within the machine-specific hardware modules to ensure the core configuration remains portable.

## Technical Optimizations

### 1. Power Management
The system utilizes **power-profiles-daemon** (PPD) for native ACPI platform profile management, paired with the **AMD P-State (active)** driver. This replaces TLP to ensure seamless negotiation with the Ryzen 6000 "Rembrandt" architecture.

#### Optimized Power Policy
The configuration implements a modern power-saving posture designed for maximum endurance while preserving the ability to spike performance:
-   **AMD P-State (EPP)**: Uses `active` mode. This allows the hardware to manage clock floors and boost spikes in microseconds.
-   **Platform Profiles**: PPD manages Lenovo's platform profiles (Quiet/Balanced/Performance) which are accessible via the desktop UI.
-   **Kernel Optimization**: Pinned to the **6.12 LTS kernel** to ensure ZFS compatibility while providing the latest `amdgpu` stability patches.
-   **Battery Health (Native)**: 
    -   Persistent charging thresholds (**75% start / 80% stop**) are enforced via a declarative **udev rule**.
    -   A helper script, `battery-travel-mode`, is provided to temporarily override these limits for 100% charging when traveling.
-   **GPU Power Management**: 
    -   Enables **GPU soft-recovery** and increased lockup timeouts to prevent hard hangs during intensive tasks like video conferencing.
    -   Sets a declarative **30W power cap** via udev for the discrete Radeon 6500M.
    -   Increases iGPU dynamic memory (**GTT**) to 8GB for smooth UI performance.
-   **Modern Standby**: Forced to `s2idle` to correctly utilize the Z16's Modern Standby capabilities and reduce sleep-state battery drain.
-   **Connectivity**: Disables ASPM on the Qualcomm WiFi card to prevent firmware crashes under high load.

### 2. Graphics and Display
-   **OLED Panel**: The `amdgpu.sg_display=0` kernel parameter is enabled to resolve a known flickering issue during Wayland compositor transitions.
-   **Hybrid GPU Architecture**: The system defaults to the integrated Radeon 680M. Intensive workloads can be offloaded to the discrete 6500M by using the `DRI_PRIME=1` environment variable.

### 3. Audio Stack
-   **Multi-Speaker Support**: Integration with **PipeWire** and the Sound Open Firmware (SOF) ensures all four speakers and the digital microphone array are properly driven.
-   **Mic Mute Indicator**: A systemd rule synchronizes the hardware LED with the software mute state.

### 4. Input Devices
-   **Haptic ForcePad**: Tuned via `libinput` to provide a modern, tactile response utilizing the `clickfinger` method.

## Post-Installation Verification

-   **Connectivity**: Verify network status via `nmtui` or the system tray applet.
-   **Scaling**: Ensure the HiDPI OLED panel is correctly scaled (defaulted to 1.15 in the user profile).
-   **Graphics**: Confirm driver initialization with `glxinfo | grep "OpenGL renderer"`.
-   **Audio**: Validate output and input levels via `pavucontrol`.

## Core Hardware Modules
The following modules contain the implementation details for these optimizations:
-   `modules/hardware/thinkpad-z16/default.nix`: Primary power and device logic.
-   `modules/hardware/thinkpad-z16/amd-gpu.nix`: Graphics drivers and acceleration.
-   `modules/hardware/thinkpad-z16/sound.nix`: PipeWire and hardware quirks.
-   `modules/hardware/thinkpad-z16/bluetooth.nix`: Controller management.

For general system management, refer to the [README.md](./README.md).
