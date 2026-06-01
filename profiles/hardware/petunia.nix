_: {
  flake.modules.nixos.hardware-petunia =
    { nixosModules, ... }:
    {
      imports = [
        nixosModules.hardware-petunia-default
      ];
    };
}
