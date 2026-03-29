_: {
  den = {
    aspects.base-aspect = {
      nixos =
        { lib, ... }:
        {
          nixpkgs.config.allowUnfree = true;

          nix.settings = {
            experimental-features = [
              "nix-command"
              "flakes"
            ];
            substituters = [
              "https://cache.nixos.org"
              "https://devenv.cachix.org"
            ];
            trusted-public-keys = [
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjE="
              "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
            ];
            trusted-users = [
              "root"
              "ddukes"
              "groot"
            ];
            max-jobs = lib.mkDefault 4;
            cores = lib.mkDefault 2;
          };

          time.timeZone = "America/New_York";
        };
    };

    # Global State Versions
    default.nixos.system.stateVersion = "25.11";
    default.homeManager.home.stateVersion = "25.11";
  };
}
