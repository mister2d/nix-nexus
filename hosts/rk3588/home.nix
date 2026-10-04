# Host: rk3588 (Armbian aarch64, standalone Home Manager).
# Registry key: flake.modules.homeManager.rk3588-home
# Composes: user-standalone-home.
_: {
  flake.modules.homeManager.rk3588-home =
    {
      pkgs,
      homeManagerModules,
      ...
    }:

    {
      imports = [ homeManagerModules.user-standalone-home ];

      # Home Configuration
      home = {
        username = "groot";
        # Standard Armbian home path for SBC fleet
        homeDirectory = "/home/groot";
        stateVersion = "25.11"; # Matching codebase standard for 2026

        # Other tools (git, htop, etc.) are included via imported modules.
        packages = with pkgs; [
          zstd
          curl
          wget
          htop
          tmux
        ];
      };
    };
}
