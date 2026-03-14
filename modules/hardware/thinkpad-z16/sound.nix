_:

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
          "libcamera" = "optional";
        };
      };
    };

    # Speaker-optimized settings (Balanced latency/power)
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 512;
        "default.clock.max-quantum" = 8192;
      };
    };
  };

  # Power management support for WirePlumber/Pipewire (Fixes UPower errors)
  services.upower.enable = true;

  # Noise suppression (Superseded by DeepFilterNet in audio-effects.nix)
  programs.noisetorch.enable = false;
}
