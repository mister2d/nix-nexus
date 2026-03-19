_:

{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    # WirePlumber configuration: Hardware support
    wireplumber = {
      enable = true;
      extraConfig."10-libcamera" = {
        "wireplumber.profiles" = {
          "main" = {
            "libcamera" = "optional";
          };
        };
      };

      # Persistent USB input monitoring: Disable session suspension to ensure immediate availability
      # Priority rules ensure the USB microphone is favored over internal sources when connected.
      extraConfig."51-source-routing" = {
        "monitor.alsa.rules" = [
          {
            matches = [ [ { "node.name" = "alsa_input.usb-HP__Inc_HyperX_SoloCast-00.HiFi__Mic__source"; } ] ];
            actions.update-props = {
              "priority.session" = 2500;
              "priority.driver" = 2500;
              "session.suspend-timeout-seconds" = 0;
              "node.pause-on-idle" = false;
            };
          }
          {
            # Internal microphones: Fallback priority for mobile/undocked use
            matches = [ [ { "node.name" = "~alsa_input.pci-*"; } ] ];
            actions.update-props = {
              "priority.session" = 1000;
              "priority.driver" = 1000;
            };
          }
        ];
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
