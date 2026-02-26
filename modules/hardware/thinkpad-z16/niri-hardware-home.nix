_:

{
  # ThinkPad Z16 Specific Niri Optimizations (Home Manager)
  programs.niri.settings = {
    # Force Niri to use the Integrated GPU (680M) for the compositor.
    # On the Z16, this is typically /dev/dri/renderD128.
    # This keeps the Discrete GPU (6500M) powered down until explicitly requested.
    debug.render-drm-device = "/dev/dri/renderD128";

    # Force all clients to Integrated GPU by default for battery savings.
    # We use the specific PCI ID to avoid "Invalid value" errors.
    # iGPU (Radeon 680M): pci-0000_67_00_0
    environment.DRI_PRIME = "pci-0000_67_00_0";

    # Vulkan GPU selection: Prevents apps from probing the dGPU.
    # This resolves "subprocesses" appearing on GPU 1 in nvtop.
    environment.MESA_VK_DEVICE_SELECT = "pci-0000_67_00_0";
  };

  # Set GPU variables globally for the user session to catch systemd services.
  home.sessionVariables = {
    DRI_PRIME = "pci-0000_67_00_0";
    MESA_VK_DEVICE_SELECT = "pci-0000_67_00_0";
  };
}
