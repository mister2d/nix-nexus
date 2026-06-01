{ nixosModules, ... }:

{
  imports = [
    nixosModules.hardware-z16-amd-gpu
    nixosModules.hardware-z16-bluetooth
    nixosModules.hardware-z16-sound
    nixosModules.hardware-z16-default
  ];
}
