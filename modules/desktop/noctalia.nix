_: {
  flake.modules.nixos.desktop-noctalia =
    { lib, ... }:
    {
      # power-profiles-daemon is required by Noctalia v5 for the power profile
      # bar widget and control-center shortcut. The remaining prerequisites
      # (networkmanager, bluetooth, upower) are expected to be set at the
      # workstation profile level; power-profiles-daemon is the only one that
      # is not guaranteed by the existing desktop baseline.
      services.power-profiles-daemon.enable = lib.mkDefault true;

      # Noctalia v5 Cachix binary cache.
      # The flake input intentionally omits inputs.nixpkgs.follows so that
      # store paths match what is pre-built in this cache. See flake.nix.
      nix.settings = {
        extra-substituters = [ "https://noctalia.cachix.org" ];
        extra-trusted-public-keys = [
          "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        ];
      };
    };
}
