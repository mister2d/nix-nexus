{
  config,
  pkgs,
  ...
}:

{
  # NVIDIA GPU Support (Proprietary Drivers)
  # Optimized for GA102 (RTX 3080)

  nixpkgs.config.allowUnfree = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  # Wayland & KMS Configuration
  # Enabling the framebuffer device and setting modesetting ensures compatibility
  # with modern Wayland compositors (Sway, Niri) on NVIDIA 545+.
  boot.kernelParams = [ "nvidia-drm.fbdev=1" ];

  # Sway Support
  # Allow Sway to execute with the proprietary NVIDIA driver despite being officially unsupported.
  programs.sway.extraOptions = [ "--unsupported-gpu" ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    nvidia = {
      # Modesetting is required for Wayland support and general stability.
      modesetting.enable = true;

      # Standard power management for desktop use.
      powerManagement.enable = false;
      powerManagement.finegrained = false;

      # Ampere support: GA102 (RTX 3080) utilizes the open-source kernel module.
      open = true;

      # NVIDIA configuration utilities.
      nvidiaSettings = true;

      # The persistence daemon ensures the driver remains loaded and the GPU
      # initialized, reducing initialization latency for graphical sessions.
      nvidiaPersistenced = true;

      # Driver version selection.
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      # Primary GPU Configuration
      # Single-GPU desktop uses sync mode and Prime offloading are disabled.
      prime = {
        offload.enable = false;
        sync.enable = false;

        # PCI Bus ID: 0c:00.0 mapped to decimal 12:0:0.
        nvidiaBusId = "PCI:12:0:0";
      };
    };

    # NVIDIA Container Toolkit (CDI) support
    # Note: Modern Docker (25.0+) supports CDI natively, enabling device discovery
    # via '--device nvidia.com/gpu=all'.
    nvidia-container-toolkit.enable = true;
  };

  # Container Runtime Integration
  # Manually configure the 'nvidia' runtime in Docker settings to maintain
  # compatibility with legacy workflows while avoiding deprecated global options.
  virtualisation.docker.daemon.settings = {
    runtimes = {
      nvidia = {
        path = "${pkgs.nvidia-container-toolkit}/bin/nvidia-container-runtime";
      };
    };
  };

  # Hardware Acceleration & Tooling
  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
    vulkan-loader
    vulkan-validation-layers
    vulkan-tools
    libva-utils
    nvidia-vaapi-driver
    nvidia-container-toolkit # Ensure toolkit is available for the manual runtime path
  ];

  # Session Environment (Wayland & Hardware Compatibility)
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Force software cursor rendering to mitigate cursor visibility issues on wlroots.
    WLR_NO_HARDWARE_CURSORS = "1";

    # Mitigate rendering artifacts and flickering in Electron applications.
    NVD_BACKEND = "direct";
  };
}
