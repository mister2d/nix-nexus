{ pkgs, ... }:

let
  # 1. Fetch the community-tested Dolby Atmos IRS for output parity
  # This provides the missing convolution data for the Z16 chassis.
  dolbyIrs = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/JackHack96/EasyEffects-Presets/master/irs/Dolby%20ATMOS%20((128K%20MP3))%201.Default.irs";
    sha256 = "sha256-9Ft1HZLFTBiGRfh/wJiGZ9WstMtvdtX+u3lVY3JCVAM=";
  };

  # 2. Output Pipeline (Dolby Atmos Convolution + Parametric EQ + Bass Enhancer)
  # Simulated Windows proprietary DSP pipeline with mid-range correction.
  outputPreset = pkgs.writeText "z16-dolby-output.json" (
    builtins.toJSON {
      output = {
        blocklist = [ ];
        plugins_order = [
          "convolver"
          "parametric_equalizer"
          "bass_enhancer"
        ];
        convolver = {
          bypass = false;
          input-gain = 0.0;
          ir-width = 100;
          kernel-path = "dolby_atmos.irs";
          output-gain = 0.0;
        };
        parametric_equalizer = {
          bypass = false;
          input-gain = 0.0;
          output-gain = 0.0;
          num-bands = 1;
          "band0" = {
            type = "Bell";
            frequency = 1000.0;
            gain = 3.0;
            q = 1.0;
            mode = "APO (DR)";
            slope = "x1";
            mute = false;
            solo = false;
            bypass = false;
          };
        };
        bass_enhancer = {
          amount = 0.5;
          blend = -1.0;
          bypass = false;
          floor-active = true;
          floor = 40.0;
          freq = 120.0;
        };
      };
    }
  );

  # 3. Input Pipeline (DeepFilterNet)
  # State-of-the-art neural noise suppression for the Z16 mic array.
  inputPreset = pkgs.writeText "z16-voice-input.json" (
    builtins.toJSON {
      input = {
        blocklist = [ ];
        plugins_order = [ "deepfilternet" ];
        deepfilternet = {
          attenuation = 60.0;
          bypass = false;
          min-processing-thresh = 0.0;
        };
      };
    }
  );

in
{
  # Ensure the DeepFilterNet ML models and LADSPA plugin are available to EasyEffects
  home.packages = with pkgs; [
    deepfilternet
  ];

  # Enable the EasyEffects Daemon in the background
  services.easyeffects = {
    enable = true;
    preset = "Z16_Dolby_Atmos";
  };

  # Wire the data and configurations into the EasyEffects XDG spec
  xdg.configFile = {
    "easyeffects/irs/dolby_atmos.irs".source = dolbyIrs;
    "easyeffects/output/Z16_Dolby_Atmos.json".source = outputPreset;
    "easyeffects/input/Z16_Studio_Mic.json".source = inputPreset;
  };
}
