# Host: hermes (NixOS x86_64 Proxmox LXC server).
# Registry key: flake.modules.nixos.hm-groot-hermes
# Composes: core-home-manager, hermes-home, user-bash, user-fish, user-terminal-home, user-terminal-oled-home, user-neovim-home, user-television-home, user-herdr-home.
_: {
  flake.modules.nixos.hm-groot-hermes =
    {
      pkgs,
      inputs,
      homeManagerModules,
      nixosModules,
      ...
    }:
    let
      pin = import ../../lib/pinned-pkgs.nix { inherit pkgs; };
      unstablePkgs = pin.pinnedWith [ inputs.nix-devshell.overlays.buildFixes ] inputs.nixpkgs-unstable;
    in
    {
      imports = [ nixosModules.core-home-manager ];
      home-manager = {
        users.groot = {
          home.stateVersion = "25.11";
          home.packages = with pkgs; [
            llm-agents.hermes-agent
            nodejs_24
            python313
            python313Packages.mcp
            uv
            git
            btop
            htop
            openssl
            ripgrep

            # agentic use packages
            context-mode
            context7-mcp
            github-mcp-server
            unstablePkgs.github-cli
            unstablePkgs.mcp-nixos
            unstablePkgs.tirith
            unstablePkgs.chromium
            mcp-server-time
            terraform-mcp-server
          ];
          imports = [
            inputs.nixvim.homeModules.nixvim
            homeManagerModules.user-bash
            homeManagerModules.user-fish
            homeManagerModules.user-terminal-home
            homeManagerModules.user-terminal-oled-home
            homeManagerModules.user-neovim-home
            homeManagerModules.user-television-home
            homeManagerModules.hermes-home
            homeManagerModules.user-herdr-home
          ];
        };
      };
    };
}
