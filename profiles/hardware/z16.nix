{ config, pkgs, ... }:

{
  imports = [
    ../../modules/hardware/thinkpad-z16/amd-gpu.nix
    ../../modules/hardware/thinkpad-z16/bluetooth.nix
    ../../modules/hardware/thinkpad-z16/sound.nix
    ../../modules/hardware/thinkpad-z16/default.nix
  ];
}
