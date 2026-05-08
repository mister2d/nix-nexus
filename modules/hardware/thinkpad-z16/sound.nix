_:

{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    # WirePlumber configuration: Hardware support and routing
    wireplumber = {
      enable = true;
      extraConfig = {
        "10-libcamera" = {
          "wireplumber.profiles" = {
            "main" = {
              "libcamera" = "optional";
            };
          };
        };
        "51-source-routing" = {
          "monitor.alsa.rules" = [
            {
              matches = [
                { "node.name" = "~alsa_input\.usb-HP__Inc_HyperX_SoloCast.*"; }
              ];
              actions = {
                update-props = {
                  "priority.session" = 3000;
                  "priority.driver" = 3000;
                  # Moderate timeout (5s) prevents "cold starts" in apps without staying on forever
                  "session.suspend-timeout-seconds" = 5;
                };
              };
            }
            {
              # Internal microphones: Fallback priority
              matches = [
                { "node.name" = "~alsa_input\.pci-.*"; }
              ];
              actions = {
                update-props = {
                  "priority.session" = 2200;
                  "priority.driver" = 2200;
                  "session.suspend-timeout-seconds" = 5;
                };
              };
            }
          ];
        };
      };
    };

    # Real-time conferencing and playback (balanced latency for ML noise suppression)
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
