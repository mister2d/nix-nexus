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

  boot.kernelParams = [ "nvidia-drm.fbdev=1" ];

  programs.sway.extraOptions = [ "--unsupported-gpu" ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    nvidia = {
      # Modesetting is required for Wayland support and general stability.
      modesetting.enable = true;

      # Nvidia power management. Standard for desktops.
      powerManagement.enable = false;
      powerManagement.finegrained = false;

      # Use the NVidia open source kernel module for Turing+ GPUs.
      # GA102 (RTX 3080) is Ampere, which is fully supported.
      open = true;

      # Enable the Nvidia settings menu.
      nvidiaSettings = true;

      # Use the stable driver version.
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      # PRIME settings (Disabled for single-GPU desktop)
      prime = {
        offload.enable = false;
        sync.enable = false;

        # Bus ID from recon: 0c:00.0 -> 12:0:0 (Decimal)
        nvidiaBusId = "PCI:12:0:0";
      };
    };

    # NVIDIA Container Toolkit (CDI) support
    nvidia-container-toolkit.enable = true;
  };

  # Optimization: Persistence daemon
  # Keeps the driver loaded and GPU initialized even when no X/Wayland session is active.
  # Reduces latency when starting graphical applications.
  systemd.services.nvidia-persistenced = {
    description = "NVIDIA Persistence Daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "forking";
      ExecStart = "${config.hardware.nvidia.package.bin}/bin/nvidia-persistenced --user root";
      Restart = "always";
    };
  };

  # Hardware acceleration and utility packages
  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
    vulkan-loader
    vulkan-validation-layers
    vulkan-tools
    libva-utils
    nvidia-vaapi-driver
  ];

  # Environment variables for Wayland/NVIDIA compatibility
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
    # Fix for some flickering in electron apps
    NVD_BACKEND = "direct";
  };
}
