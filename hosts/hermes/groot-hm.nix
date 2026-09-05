# Host: hermes (NixOS x86_64 Proxmox LXC server).
# Registry key: flake.modules.nixos.hm-groot-hermes
# Composes: core-home-manager, hermes-home, user-bash, user-fish, user-terminal-home, user-terminal-oled-home, user-neovim-home, user-television-home, user-herdr-home.
_: {
  flake.modules.nixos.hm-groot-hermes =
    {
      pkgs,
      lib,
      inputs,
      homeManagerModules,
      nixosModules,
      ...
    }:
    let
      inherit (inputs.self) overlays;
      pin = import ../../lib/pinned-pkgs.nix { inherit pkgs; };
      unstablePkgs = pin.pinnedWith [ overlays.buildFixes ] inputs.nixpkgs-unstable;
      context-mode-pkg = import ../../lib/context-mode.nix { inherit pkgs lib; };
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
            context-mode-pkg
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
