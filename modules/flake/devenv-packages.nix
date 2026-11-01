# Flake assembly: packages. Drops devenv-up and devenv-test from flake.packages.
# devenv's flake module still adds both for every shell, each wrapped in a deprecation
# warning, so every `nix flake check` warned. Nothing here uses them: `devenv up` and
# `devenv test` replace them. The other packages, the container images among them, stay.
{ config, lib, ... }:
{
  flake.packages = lib.mkForce (
    lib.mapAttrs (
      _system: s:
      builtins.removeAttrs s.packages [
        "devenv-up"
        "devenv-test"
      ]
    ) config.allSystems
  );
}
