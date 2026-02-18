{ config, pkgs, ... }:

{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    
    # Enable libcamera support in WirePlumber
    wireplumber.enable = true;
    wireplumber.extraConfig."10-libcamera" = {
      "wireplumber.profiles" = {
        "main" = {
          "libcamera" = "required";
        };
      };
    };

    # Low-latency and hardware-optimized settings
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 32;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 1024;
      };
    };
  };

  # Power management support for WirePlumber/Pipewire (Fixes UPower errors)
  services.upower.enable = true;
  
  # Noise suppression
  programs.noisetorch.enable = true;
}
