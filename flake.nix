{
  description = "Portable NixOS Configuration Framework";

  inputs = {
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

    # Niri - Scrollable-tiling Wayland compositor
    niri.url = "github:YaLTeR/niri";

    # DankMaterialShell - Material Design Shell for Wayland
    dms.url = "github:AvengeMedia/DankMaterialShell";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
      home-manager,
      pre-commit-hooks,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      systems = [ "x86_64-linux" ];
      forAllSystems = lib.genAttrs systems;
    in
    {
      # Tree-wide Validation and Linting
      checks = forAllSystems (system: {
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            # Standard Formatting (RFC 166)
            nixfmt-rfc-style.enable = true;

            # Linting: Unused code and anti-patterns
            deadnix.enable = true;
            statix.enable = true;
          };
        };
      });

      # Developer Environment
      # Usage: 'nix develop' to enter environment and install hooks
      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          inherit (self.checks.${system}.pre-commit-check) shellHook;
          buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
        };
      });

      nixosConfigurations = {
        # Hostname: sweet16
        sweet16 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            # Hardware specific configuration
            nixos-hardware.nixosModules.lenovo-thinkpad-z
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-gpu-amd
            nixos-hardware.nixosModules.common-pc-ssd

            # Main configuration entry point
            ./hosts/z16/default.nix

            # Home Manager configuration
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "bak";
                extraSpecialArgs = {
                  inherit inputs;
                };
                users.ddukes = {
                  imports = [
                    ./modules/user/home.nix
                    ./modules/hardware/thinkpad-z16/kanshi-home.nix
                  ];
                };
              };
            }
          ];
        };
      };
    };
}
