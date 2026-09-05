# ThinkPad Z16 Gen 1: Hardware-Specific Optimizations

This guide covers the hardware configurations applied to the ThinkPad Z16
Gen 1 (OLED model with hybrid AMD graphics). These settings stay inside
machine-specific hardware modules, so the core configuration stays
portable.

## Technical Optimizations

### 1. Power Management
The system uses **power-profiles-daemon** (PPD) for native ACPI platform
profile management, paired with the **AMD P-State (active)** driver. This
replaces TLP and gives smooth negotiation with the Ryzen 6000 "Rembrandt"
architecture.

#### Optimized Power Policy
The configuration sets a power-saving posture built for maximum endurance,
while it keeps the ability to spike performance:
-   **AMD P-State (EPP)**: Uses `active` mode. The hardware manages clock floors and boost spikes in microseconds.
-   **Platform Profiles**: PPD manages Lenovo's platform profiles (Quiet/Balanced/Performance). You reach these through the desktop UI.
-   **Kernel Optimization**: Pinned to the **6.12 LTS kernel**. This keeps ZFS compatibility and gives the latest `amdgpu` stability patches.
-   **Battery Health (Native)**:
    -   A declarative **udev rule** enforces persistent charging thresholds (**75% start / 80% stop**).
    -   A helper script, `battery-travel-mode`, lets you override these limits for 100% charging when you travel.
-   **GPU Power Management**:
    -   Enables **GPU soft-recovery** and raises lockup timeouts. This prevents hard hangs during intensive tasks like video conferencing.
    -   Sets a declarative **30W power cap** through udev for the discrete Radeon 6500M.
    -   Raises iGPU dynamic memory (**GTT**) to 8GB for smooth UI performance.
-   **Modern Standby**: Forced to `s2idle`. This correctly uses the Z16's Modern Standby capability and reduces sleep-state battery drain.
-   **Connectivity**: Disables ASPM on the Qualcomm WiFi card to prevent firmware crashes under high load.

### 2. Graphics and Display
-   **OLED Panel**: The `amdgpu.sg_display=0` kernel parameter is enabled. It resolves a known flickering issue during Wayland compositor transitions.
-   **Hybrid GPU Architecture**: The system defaults to the integrated Radeon 680M. You can offload intensive workloads to the discrete 6500M with the `DRI_PRIME=1` environment variable.

### 3. Audio Stack
-   **Multi-Speaker Support**: Integration with **PipeWire** and the Sound Open Firmware (SOF) drives all four speakers and the digital microphone array correctly.
-   **Mic Mute Indicator**: A systemd rule syncs the hardware LED with the software mute state.

### 4. Input Devices
-   **Haptic ForcePad**: Tuned through `libinput` for a modern, tactile response with the `clickfinger` method.

## Post-Installation Verification

-   **Connectivity**: Verify network status through `nmtui` or the system tray applet.
-   **Scaling**: Confirm the HiDPI OLED panel is scaled correctly (defaults to 1.15 in the user profile).
-   **Graphics**: Confirm driver initialization with `glxinfo | grep "OpenGL renderer"`.
-   **Audio**: Confirm output and input levels through `pavucontrol`.

## Core Hardware Modules
These modules hold the implementation details for these optimizations:
-   `modules/hardware/thinkpad-z16/default.nix`: Primary power and device logic.
-   `modules/hardware/thinkpad-z16/amd-gpu.nix`: Graphics drivers and acceleration.
-   `modules/hardware/thinkpad-z16/sound.nix`: PipeWire and hardware quirks.
-   `modules/hardware/thinkpad-z16/bluetooth.nix`: Controller management.

For general system management, refer to the [README.md](./README.md).
