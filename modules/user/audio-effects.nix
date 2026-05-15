_:

let
  # Impulse response files extracted from the official Lenovo Z16 Windows driver (ds557051)
  irsPath = ./../../assets/audio/irs;

  # Input pipeline presets
  inputPresetsPath = ./../../assets/audio/presets/input;

  # Output pipeline presets
  enhancedPresetsPath = ./../../assets/audio/presets/output/enhanced;
  desktopPresetsPath = ./../../assets/audio/presets/output/desktop;

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

in
{
  # Enable the EasyEffects Daemon in the background
  services.easyeffects = {
    enable = true;
    preset = "Z16-Music-Balanced";
  };

  # Wire assets into EasyEffects XDG spec for v8.x
  home.file =
    (mapFiles ".local/share/easyeffects/irs" irsPath)
    // (mapFiles ".local/share/easyeffects/input" inputPresetsPath)
    // (mapFiles ".local/share/easyeffects/output" enhancedPresetsPath)
    // (mapFiles ".local/share/easyeffects/output" desktopPresetsPath);
}
