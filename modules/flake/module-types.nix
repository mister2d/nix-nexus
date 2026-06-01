{ lib, ... }:
{
  options = {
    flake.modules = {
      nixos = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw;
        default = { };
        description = "Registry of named NixOS modules for dendritic composition.";
      };
      homeManager = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw;
        default = { };
        description = "Registry of named Home Manager modules for dendritic composition.";
      };
    };
    flake.homeConfigurations = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = { };
      description = "Standalone Home Manager configurations.";
    };
  };
}
