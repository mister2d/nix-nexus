let
  gib = n: n * 1024 * 1024 * 1024;
in
_: {
  flake.modules.nixos.core-nix = _: {
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      substituters = [
        "https://cache.nixos.org"
        "https://devenv.cachix.org"
        "https://nix-amd-ai.cachix.org"
      ];
      trusted-public-keys = [
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
