# Flake assembly: registry-type. Sets modules (a flake-parts option, not a flake output) and flake.homeConfigurations.
# Declares the option types every dendritic registry file writes into.
{ lib, ... }:
{
  options = {
    # A submodule, as flake.modules was under the `flake` submodule: definitions from
    # several files then merge in the same order as before, so no host's closure moved.
    modules = lib.mkOption {
      type = lib.types.submoduleWith {
        modules = [
          {
            options = {
              nixos = lib.mkOption {
                type = lib.types.lazyAttrsOf lib.types.deferredModule;
                default = { };
                description = "Registry of named NixOS modules for dendritic composition.";
              };
              homeManager = lib.mkOption {
                type = lib.types.lazyAttrsOf lib.types.deferredModule;
                default = { };
                description = "Registry of named Home Manager modules for dendritic composition.";
              };
            };
          }
        ];
      };
      default = { };
      description = "Registry of named modules by class (nixos, homeManager) for dendritic composition.";
    };
    flake.homeConfigurations = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = { };
      description = "Standalone Home Manager configurations.";
    };
  };
}
