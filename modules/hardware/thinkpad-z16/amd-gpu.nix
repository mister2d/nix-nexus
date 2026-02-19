{ pkgs, ... }:

{
  # Graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = false; # Disabled: No Steam/legacy 32-bit apps needed
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
    ];
  };

  services.xserver.videoDrivers = [ "amdgpu" ];

  environment.systemPackages = with pkgs; [
    nvtopPackages.amd
  ];

  # Hardware Acceleration
  environment.variables = {
    # VAAPI / VDPAU
    LIBVA_DRIVER_NAME = "radeonsi";
    VDPAU_DRIVER = "radeonsi";
  };
}
