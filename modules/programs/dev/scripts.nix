# Merged into: flake.modules.nixos.development-default
# Configures: custom scripts (battery-alert, system-stats, audio-selector) as system packages.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.development-default =
    { pkgs, ... }:
    let
      scripts = import ../../../lib/custom-scripts.nix { inherit pkgs; };
    in
    {
      environment.systemPackages = [
        scripts.battery-alert
        scripts.system-stats
        scripts.audio-selector
      ];
    };
}
