{ inputs, ... }:
{
  # ============================================================================
  # ThinkPad Z16 Hardware Aspect: Workstation Optimization
  # ============================================================================

  den.aspects.hw-z16-aspect = {
    nixos = { ... }: {
      imports = [
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z
        inputs.nixos-hardware.nixosModules.common-cpu-amd
        inputs.nixos-hardware.nixosModules.common-gpu-amd
        inputs.nixos-hardware.nixosModules.common-pc-ssd
      ];

      # Bluetooth & Sound (Ambiently required by a mobile workstation)
      hardware.bluetooth.enable = true;
      services.blueman.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
      };
    };
  };
}
