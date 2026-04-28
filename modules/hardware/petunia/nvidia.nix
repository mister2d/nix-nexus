{
  pkgs,
  ...
}:

{
  imports = [
    ../nvidia.nix
  ];

  # Enable the shared NVIDIA aspect with pinned driver/CUDA
  nix-nexus.hardware.nvidia.enable = true;

  # Machine-specific overrides for Petunia (RTX 3080 Desktop)
  hardware.nvidia = {
    # PCI Bus ID: 0c:00.0 mapped to decimal 12:0:0.
    prime.nvidiaBusId = "PCI:12:0:0";

    # Standard power management for desktop use.
    powerManagement.enable = false;
    powerManagement.finegrained = false;
  };

  # Wayland & KMS Configuration
  boot.kernelParams = [ "nvidia-drm.fbdev=1" ];

  # Sway Support
  programs.sway.extraOptions = [ "--unsupported-gpu" ];

  # NVIDIA Container Toolkit (CDI) support
  hardware.nvidia-container-toolkit.enable = true;

  # Container Runtime Integration
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
    nvidia-container-toolkit
  ];

  # Session Environment (Petunia-specific tweaks)
  environment.sessionVariables = {
    # Force software cursor rendering to mitigate cursor visibility issues on wlroots.
    WLR_NO_HARDWARE_CURSORS = "1";

    # Mitigate rendering artifacts and flickering in Electron applications.
    NVD_BACKEND = "direct";
  };
}
