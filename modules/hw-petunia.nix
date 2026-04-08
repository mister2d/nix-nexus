{ inputs, ... }:
{
  # ============================================================================
  # Petunia Hardware Aspect: High-Performance Compute & NVIDIA Stack
  # ============================================================================

  den.aspects.hw-petunia-aspect = {
    nixos = { lib, ... }: {
      imports = [
        inputs.nixos-hardware.nixosModules.common-cpu-amd
        inputs.nixos-hardware.nixosModules.common-gpu-nvidia
        inputs.nixos-hardware.nixosModules.common-pc-ssd
      ];

      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement.enable = false;
        powerManagement.finegrained = false;
        open = false; # Proprietary drivers for maximum performance
        nvidiaSettings = true;
        prime.offload.enable = lib.mkForce false;
        prime.sync.enable = lib.mkForce false;
      };
    };
  };
}
