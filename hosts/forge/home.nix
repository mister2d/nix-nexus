# Host: forge (Linux x86_64, standalone Home Manager).
# Registry key: flake.modules.homeManager.forge-home
# Composes: user-standalone-home.
_: {
  flake.modules.homeManager.forge-home =
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
        homeDirectory = "/home/groot";
        stateVersion = "25.11";

        # Basic packages
        packages = with pkgs; [
          zstd
          curl
          wget
          htop
          nvtopPackages.nvidia # For monitoring the Quadro T2000
        ];
      };

      nix-nexus.user.herdr.claudeIntegration.enable = true;
    };
}
