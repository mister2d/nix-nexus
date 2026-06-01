_: {
  flake.modules.nixos.programs-scripts =
    { pkgs, ... }:
    let
      scripts = import ../../lib/custom-scripts.nix { inherit pkgs; };
    in
    {
      environment.systemPackages = [
        scripts.battery-alert
        scripts.system-stats
        scripts.audio-selector
      ];
    };
}
