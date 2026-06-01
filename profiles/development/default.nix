_: {
  flake.modules.nixos.development-default =
    { nixosModules, ... }:
    {
      imports = [
        nixosModules.programs-common
        nixosModules.programs-dev
        nixosModules.programs-scripts
      ];
    };
}
