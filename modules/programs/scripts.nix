{ pkgs, ... }:

let
  scripts = import ./custom-scripts.nix { inherit pkgs; };
in
{
  environment.systemPackages = [
    scripts.battery-alert
    scripts.system-stats
    scripts.audio-selector
  ];
}
