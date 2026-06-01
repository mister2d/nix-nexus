_: {
  flake.modules.nixos.hardware-petunia-default =
    { nixosModules, ... }:
    {
      imports = [
        nixosModules.hardware-petunia-ryzen
        nixosModules.hardware-petunia-rdna4
      ];
    };
}
