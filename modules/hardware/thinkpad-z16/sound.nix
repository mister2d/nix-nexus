# Merged into: flake.modules.nixos.hardware-z16
# Configures: PipeWire audio routing and the mic-mute LED sync service.
# Imported by: hosts/sweet16/default.nix (sweet16-default).
_: {
  flake.modules.nixos.hardware-z16 =
    { pkgs, ... }:
    let
      sampleRate = 48000; # Hz
      quantum = 1024; # samples
      minQuantum = 512; # samples
      maxQuantum = 8192; # samples
    in
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
                      "session.suspend-timeout-seconds" = 0;
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
            "default.clock.rate" = sampleRate;
            "default.clock.quantum" = quantum;
            "default.clock.min-quantum" = minQuantum;
            "default.clock.max-quantum" = maxQuantum;
          };
        };
      };

      # Power management support for WirePlumber/Pipewire (Fixes UPower errors)
      services.upower.enable = true;

      # EasyEffects applies RNNoise for noise suppression. NoiseTorch stays disabled.
      programs.noisetorch.enable = false;

      # Sync platform::micmute LED with PipeWire source mute state.
      # Subscribes to pactl events and writes LED brightness on every source change.
      # Requires GROUP="audio" MODE="0664" on the sysfs LED node (set in default.nix).
      systemd.user.services.mic-mute-led-sync = {
        description = "Sync ThinkPad mic mute LED with PipeWire source mute state";
        wantedBy = [ "pipewire-pulse.service" ];
        after = [ "pipewire-pulse.service" ];
        serviceConfig = {
          Type = "simple";
          ExecStart =
            let
              script = pkgs.writeShellScript "mic-mute-led-sync" ''
                LED=/sys/class/leds/platform::micmute/brightness

                sync_led() {
                  case "$(${pkgs.pulseaudio}/bin/pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null)" in
                    *yes*) echo 1 > "$LED" ;;
                    *no*)  echo 0 > "$LED" ;;
                  esac
                }

                sync_led

                ${pkgs.pulseaudio}/bin/pactl subscribe | while IFS= read -r line; do
                  case "$line" in
                    *"Event 'change' on source"*) sync_led ;;
                  esac
                done
              '';
            in
            "${script}";
          Restart = "on-failure";
          RestartSec = 2;
        };
      };
    };
}
