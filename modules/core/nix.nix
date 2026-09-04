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
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjE="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "nix-amd-ai.cachix.org-1:F4OU4vw/lV2oiG6SBHZ+nqjl4EFJuqI4X9A7pvaBmhQ="
      ];

      trusted-users = [
        "root"
        "ddukes"
        "groot"
      ];
    };

    time.timeZone = "America/New_York";
  };
}
