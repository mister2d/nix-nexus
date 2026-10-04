# Host: dualie (Debian x86_64, standalone Home Manager).
# Registry key: flake.modules.homeManager.dualie-home
# Composes: user-standalone-home.
_: {
  flake.modules.homeManager.dualie-home =
    {
      pkgs,
      inputs,
      homeManagerModules,
      ...
    }:

    let
      pin = import ../../lib/pinned-pkgs.nix { inherit pkgs; };

      unstable-pkgs = pin.pinned inputs.nixpkgs-unstable;
    in
    {
      imports = [ homeManagerModules.user-standalone-home ];

      # Home Configuration
      home = {
        username = "groot";
        homeDirectory = "/mnt/ironhide/home/groot";
        stateVersion = "25.11"; # Matching codebase standard for 2026

        # Other tools (git, htop, etc.) are included via imported modules.
        packages = with pkgs; [
          zstd
          curl
          wget
          unstable-pkgs.llama-swap
        ];
      };
    };
}
