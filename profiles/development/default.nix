{ nixosModules, ... }:

{
  imports = [
    nixosModules.programs-common
    nixosModules.programs-dev
    nixosModules.programs-scripts
  ];
}
