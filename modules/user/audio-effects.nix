{ pkgs, ... }:

let
  # 1. Output Pipeline: High-fidelity Dolby DAX3 Tuning
  # These assets were extracted from the official Lenovo Z16 Windows driver (ds557051)
  # using the 'speaker-tuning-to-easyeffects' converter.
  irsPath = ./../../assets/audio/irs;
  presetsPath = ./../../assets/audio/presets;

  # Helper to bulk map assets from the repository to the EasyEffects XDG spec
  # Note: EasyEffects 8.x+ uses ~/.local/share/easyeffects/ instead of ~/.config/
  mapFiles =
    prefix: path:
    let
      files = builtins.attrNames (builtins.readDir path);
    in
    builtins.listToAttrs (
      map (name: {
        name = "${prefix}/${name}";
        value = {
          source = "${path}/${name}";
        };
      }) files
    );

  # 2. Input Pipeline (DeepFilterNet)
  # State-of-the-art neural noise suppression for the Z16 mic array.
  inputPreset = pkgs.writeText "Z16_Studio_Mic.json" (
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
    preset = "Dolby-Music-Balanced";
  };

  # Wire assets into EasyEffects XDG spec for v8.x
  home.file =
    (mapFiles ".local/share/easyeffects/irs" irsPath)
    // (mapFiles ".local/share/easyeffects/output" presetsPath)
    // {
      ".local/share/easyeffects/input/Z16_Studio_Mic.json".source = inputPreset;
    };
}
