{
  lib,
  ...
}:
{

  den.aspects.user-groot-aspect = lib.mkForce {
    homeManager =
      { pkgs, ... }:
      {
        home = {
          username = "groot";
          homeDirectory = "/home/groot";
          stateVersion = "25.11";
          sessionPath = [ "$HOME/bin" ];
          packages = with pkgs; [
            zstd
            curl
            wget
            htop
            nvtopPackages.nvidia
          ];
        };

        programs.dev-home = {
          enable = true;
          enableMcpServers = true;
          enableLlmAgents = true;
        };

        programs.home-manager.enable = true;
        nixpkgs.config.allowUnfree = true;
      };
  };
}
