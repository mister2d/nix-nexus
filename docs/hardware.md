# ThinkPad Z16 Gen 1: Hardware-Specific Optimizations

This guide details the technical configurations and hardware optimizations applied to the ThinkPad Z16 Gen 1 (OLED model with hybrid AMD graphics). These settings are isolated within the machine-specific hardware modules to ensure the core configuration remains portable.

## Technical Optimizations

### 1. Power Management
Standard power profiles are replaced by **TLP** to provide granular control over the discrete Radeon 6500M GPU and PCIe ASPM (Active State Power Management) states.

#### "Max Battery" Profile Refinements
The configuration implements an aggressive power-saving posture designed for maximum endurance while preserving the ability to spike performance:
-   **AMD P-State (EPP)**: Uses `active` mode with `balance_power` on battery. This drops the clock floor significantly while allowing hardware-managed boost spikes in microseconds.
-   **Platform Profiles**: Leverages Lenovo's `low-power` platform profile on battery to reduce internal power rails and fan activity.
-   **GPU Power Management**: 
    -   Forces the discrete Radeon 6500M into **D3Cold** (0W) when idle via `powersupersave` ASPM.
    -   Sets a declarative **30W power cap** via udev to match the VBIOS limit and avoid driver errors.
    -   Increases iGPU dynamic memory (**GTT**) to 8GB for smooth UI performance without reserving physical RAM.
-   **Aggressive Peripherals**: Enables NVMe runtime power management (`auto`), WiFi power saving, and USB autosuspend on battery.
-   **OLED Optimization**: Enables AMD **ABM (Adaptive Backlight Management)** at level 4 to reduce panel power draw.

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
