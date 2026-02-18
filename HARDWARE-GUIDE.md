# ThinkPad Z16 Gen 1: Hardware-Specific Optimizations

This guide outlines the specific hardware configurations and optimizations applied for the ThinkPad Z16 Gen 1 (OLED model with hybrid AMD graphics). These settings are isolated in the `modules/hardware/thinkpad-z16/` branch of the project to ensure portability of the core system logic.

## 🚀 Key Optimizations

### 1. Power Management (TLP)
While many modern laptops use `power-profiles-daemon`, we utilize **TLP** for more granular control over the Z16's discrete Radeon 6500M GPU and PCIe ASPM states. 
-   **AMD P-State**: Optimized to use the `amd_pstate=active` driver for better power/performance balance.
-   **Battery Health**: Configured to limit charging between 75-80% to extend long-term battery lifespan.

### 2. Display & Graphics (OLED)
-   **OLED Flickering**: Includes the `amdgpu.sg_display=0` kernel parameter. This resolves a known issue on the Z16's OLED panel where flickering occurs during Wayland transitions.
-   **Hybrid Graphics**: Defaults to the integrated 680M GPU for power savings. To leverage the discrete 6500M GPU for intensive tasks (like LLM inference or development), prefix your command with `DRI_PRIME=1`.

### 3. Audio & Mic
-   **4-Speaker Setup**: Configured with **Pipewire** and SOF (Sound Open Firmware) to properly support the Z16's internal 4-speaker array.
-   **Mic LED**: Includes a systemd rule to correctly sync the Mic Mute LED with the system's actual audio-micmute state.

### 4. Haptic Touchpad
-   The Z16 "ForcePad" requires `libinput` tuning. The desktop configuration mimics the modern haptic feel by utilizing the `clickfinger` method.

## 🛠️ Post-Installation Checklist

-   [ ] **WiFi**: Verify connectivity via `nmtui` or the network applet in the system tray.
-   [ ] **Display Scaling**: Check scaling in Sway (set to 1.25x by default for the OLED panel in `modules/user/home.nix`).
-   [ ] **GPU**: Run `glxinfo | grep "OpenGL renderer"` to ensure the AMD drivers are active.
-   [ ] **Audio**: Test speakers and mic via `pavucontrol` or similar tools.
-   [ ] **ZFS**: Verify pool health using `zpool status`.

## 💎 Specific Hardware Files
All hardware-specific logic for the ThinkPad Z16 can be found in:
-   `modules/hardware/thinkpad-z16/default.nix`: Main power and device logic.
-   `modules/hardware/thinkpad-z16/amd-gpu.nix`: Graphics drivers and Vulkan support.
-   `modules/hardware/thinkpad-z16/sound.nix`: Pipewire and audio hardware quirks.
-   `modules/hardware/thinkpad-z16/bluetooth.nix`: Bluetooth controller and power-on settings.

For general system usage and how to apply these settings, please refer to the main [README.md](./README.md).
