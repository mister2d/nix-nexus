{
  pkgs,
  inputs,
  homeManagerModules,
  ...
}:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
    extraSpecialArgs = {
      inherit (inputs) self;
      inherit inputs;
    };
    users.groot = {
      home.stateVersion = "25.11";
      home.packages = with pkgs; [
        tailscale
        nodejs_24
        python314
        git
        btop
        htop
        openssl
      ];
      imports = [
        inputs.nixvim.homeModules.nixvim
        homeManagerModules.user-bash
        homeManagerModules.user-terminal-home
        homeManagerModules.user-neovim-home
        homeManagerModules.openclaw-home
      ];
    };
  };
}
