# Registry key: flake.modules.homeManager.user-audio-effects
# Configures: the EasyEffects daemon, Z16 impulse responses, and preset assets.
# Imported by: modules/user/home.nix (user-home).
{ lib, ... }:
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
      files = lib.attrNames (builtins.readDir path);
    in
    lib.listToAttrs (
      map (name: {
        name = "${prefix}/${name}";
        value = {
          source = "${path}/${name}";
        };
      }) files
    );

in
{
  flake.modules.homeManager.user-audio-effects = {
    # Enable the EasyEffects Daemon in the background
    services.easyeffects = {
      enable = true;
      preset = "Z16-Music-Balanced";
    };

    # Ensure EasyEffects starts after PipeWire is ready, not just after the
    # graphical session target fires. Without this, the service races PipeWire
    # on some boots and the 5s Restart=on-failure delay causes audible silence.
    systemd.user.services.easyeffects = {
      Unit.After = [
        "graphical-session.target"
        "pipewire.service"
        "pipewire-pulse.service"
      ];
    };

    # Wire assets into EasyEffects XDG spec for v8.x
    home.file =
      (mapFiles ".local/share/easyeffects/irs" irsPath)
      // (mapFiles ".local/share/easyeffects/input" inputPresetsPath)
      // (mapFiles ".local/share/easyeffects/output" enhancedPresetsPath)
      // (mapFiles ".local/share/easyeffects/output" desktopPresetsPath);
  };
}
