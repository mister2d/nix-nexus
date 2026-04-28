{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  options.nix-nexus.hardware.nvidia = {
    enable = lib.mkEnableOption "NVIDIA GPU support with pinned driver and CUDA";
    pinCuda = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to pin cudaPackages to 13.1 for this host";
    };
  };

  config = lib.mkIf config.nix-nexus.hardware.nvidia.enable {
    nixpkgs.config.allowUnfree = true;

    services.xserver.videoDrivers = [ "nvidia" ];

    # NVIDIA Driver Pinning (Inheritable Version)
    hardware.nvidia = {
      modesetting.enable = lib.mkDefault true;
      open = lib.mkDefault true;
      nvidiaSettings = lib.mkDefault true;
      nvidiaPersistenced = lib.mkDefault true;

      # Single-GPU systems should have PRIME disabled by default.
      # Multi-GPU/Laptop systems can override these in host-specific configs.
      prime = {
        offload.enable = lib.mkDefault false;
        sync.enable = lib.mkDefault false;
      };

      package = lib.mkDefault (
        config.boot.kernelPackages.nvidiaPackages.mkDriver {
          version = "590.48.01";
          sha256_64bit = "sha256-ueL4BpN4FDHMh/TNKRCeEz3Oy1ClDWto1LO/LWlr1ok=";
          sha256_aarch64 = "sha256-FOz7f6pW1NGM2f74kbP6LbNijxKj5ZtZ08bm0aC+/YA=";
          openSha256 = "sha256-hECHfguzwduEfPo5pCDjWE/MjtRDhINVr4b1awFdP44=";
          settingsSha256 = "sha256-NWsqUciPa4f1ZX6f0By3yScz3pqKJV1ei9GvOF8qIEE=";
          persistencedSha256 = "sha256-wsNeuw7IaY6Qc/i/AzT/4N82lPjkwfrhxidKWUtcwW8=";
        }
      );
    };

    # Apply CUDA 13.1 overlay if enabled
    nixpkgs.overlays = lib.mkIf config.nix-nexus.hardware.nvidia.pinCuda [
      (final: _: {
        cudaPackages =
          (import inputs.nixpkgs-unstable {
            inherit (final) system;
            config.allowUnfree = true;
          }).cudaPackages_13_1;
      })
    ];

    environment.systemPackages = lib.mkIf config.nix-nexus.hardware.nvidia.pinCuda [
      pkgs.cudaPackages.cudatoolkit
    ];

    # Common NVIDIA Environment
    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "nvidia";
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    };
  };
}
