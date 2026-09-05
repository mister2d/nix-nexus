# Registry key: flake.modules.nixos.core-home-manager
# Configures: Home Manager integration defaults for every NixOS host.
# Imported by: hosts/avina/ddukes-hm.nix (hm-ddukes-avina), hosts/sweet16/ddukes-hm.nix (hm-ddukes-sweet16), hosts/petunia/ddukes-hm.nix (hm-ddukes-petunia), hosts/hermes/groot-hm.nix (hm-groot-hermes).
_: {
  flake.modules.nixos.core-home-manager =
    { inputs, homeManagerModules, ... }:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak-$(date +%Y%m%d%H%M%S)";
        extraSpecialArgs = {
          inherit (inputs) self;
          inherit inputs homeManagerModules;
        };
      };
    };
}
