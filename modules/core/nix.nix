# Registry key: flake.modules.nixos.core-nix
# Configures: Nix package (pinned to 2.35), Nix daemon settings, binary caches, trusted users, and garbage collection.
# Imported by: profiles/server/default.nix (server-default), profiles/workstation/default.nix (workstation-default).
let
  gib = n: n * 1024 * 1024 * 1024;
  bincache = import ../../lib/bincache.nix;
in
_: {
  flake.modules.nixos.core-nix =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cacheSettings = [
        "substituters"
        "extra-substituters"
        "trusted-substituters"
        "trusted-public-keys"
        "extra-trusted-public-keys"
      ];
      bannedCache = [
        "xuyh0120"
        "lantian"
      ];
      offenders = lib.concatMap (
        name:
        builtins.filter (entry: lib.any (b: lib.hasInfix b entry) bannedCache) (
          config.nix.settings.${name} or [ ]
        )
      ) cacheSettings;
    in
    {
      # Fails evaluation if the compromised CachyOS cache is configured.
      assertions = [
        {
          assertion = offenders == [ ];
          message = "Compromised binary cache configured (attic.xuyh0120.win/lantian, reported 2026-10-18, see docs/cachyos-kernel.md): ${builtins.concatStringsSep ", " offenders}";
        }
      ];

      nix.package = pkgs.nixVersions.nix_2_35;

      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];

        # The internal cache is tried first; the upstream caches stay as fallback.
        substituters = [
          bincache.url
          "https://cache.nixos.org"
          "https://devenv.cachix.org"
          "https://nix-amd-ai.cachix.org"
        ];
        trusted-public-keys = bincache.publicKeys ++ [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
          "nix-amd-ai.cachix.org-1:F4OU4vw/lV2oiG6SBHZ+nqjl4EFJuqI4X9A7pvaBmhQ="
        ];

        trusted-users = [
          "root"
          "ddukes"
          "groot"
        ];

        # The store is also the read-only lower layer for permafrost microvm guests.
        # Dedup runs only on the host.
        auto-optimise-store = true;

        # Min-free triggers garbage collection during builds.
        # GC runs until max-free bytes are free.
        min-free = gib 5;
        max-free = gib 20;
      };

      time.timeZone = "America/New_York";
    };
}
