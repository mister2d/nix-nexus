{ nixosModules, ... }:

{
  imports = [
    nixosModules.hardware-petunia-default
  ];
}
