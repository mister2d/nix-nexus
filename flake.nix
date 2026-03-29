{
  description = "Portable NixOS Configuration Framework — Dendritic Den v0.13.0";

  inputs = {
    # Den - Dendritic Nix Configuration Framework (v0.13.0)
    den.url = "github:vic/den";
    den.inputs.nixpkgs.follows = "nixpkgs";

    # Import-tree - Directory discovery
    import-tree.url = "github:vic/import-tree";

    # Flake-parts - Modular flake orchestration
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Official NixOS package source - Using 25.11 for 2026 stability
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Unstable for absolute latest packages
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Hardware quirks
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Home Manager - Standard for user-level config
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pin Google Chrome version (currently 145.0.7632.75)
    nixpkgs-chrome.url = "github:nixos/nixpkgs/fa56d7d6de78f5a7f997b0ea2bc6efd5868ad9e8";

    # Declarative Git Hooks
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # MCP Server Framework
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # AI Coding Agents (including pi and gemini-cli)
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Niri - Scrollable-tiling Wayland compositor
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "niri-nixpkgs";
    };
    niri-nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # DankMaterialShell - Material Design Shell for Wayland
    dms.url = "github:AvengeMedia/DankMaterialShell/v1.4.2";

    # Disko - Declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nixvim - Neovim configuration via Nix
    nixvim.url = "github:nix-community/nixvim/nixos-25.11";

    # Stable Matrix Stack Components (Pinned to 25.11 for stability)
    pkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    # Pinned package versions
    pkgs-nomad.url = "github:nixos/nixpkgs/ae67888ff7ef9dff69b3cf0cc0fbfbcd3a722abe";
    pkgs-hashicorp.url = "github:nixos/nixpkgs/a1bab9e494f5f4939442a57a58d0449a109593fe";
    pkgs-terraform.url = "github:nixos/nixpkgs/7d2ae6d8b8b697b5114a4249d0d958ee5f23d8fe";
    pkgs-talos.url = "github:nixos/nixpkgs/ee09932cedcef15aaf476f9343d1dea2cb77e261";
    pkgs-vlc.url = "github:nixos/nixpkgs/41965737c1797c1d83cfb0b644ed0840a6220bd1";
    pkgs-apps.url = "github:nixos/nixpkgs/f665af0cdb70ed27e1bd8f9fdfecaf451260fc55";
    pkgs-ceph.url = "github:nixos/nixpkgs/d1c15b7d5806069da59e819999d70e1cec0760bf";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
