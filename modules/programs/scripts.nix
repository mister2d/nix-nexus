_: {
  flake.modules.nixos.development-default =
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
