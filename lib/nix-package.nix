# The Nix version every host runs: NixOS hosts via nix.package, standalone Home Manager hosts
# via nix.package and home.packages. Imported by relative path: modules/core/nix.nix,
# modules/user/standalone-home.nix, modules/user/bincache-home.nix.
pkgs: pkgs.nixVersions.nix_2_35
