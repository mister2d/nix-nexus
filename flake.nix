{
  description = "Portable NixOS Configuration Framework";

  inputs = {
    # Official NixOS package source - Using 25.11 for 2026 stability
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Add Devenv 2.0 for native development environments
    devenv = {
      url = "github:cachix/devenv";
    };

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
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
    pkgs-hashicorp.url = "github:nixos/nixpkgs/a1bab9e494f5f4939442a57a58d0449a109593fe"; # vault, consul, helm, envsubst, ipmitool
    pkgs-terraform.url = "github:nixos/nixpkgs/7d2ae6d8b8b697b5114a4249d0d958ee5f23d8fe"; # terraform, mqtt-explorer, prusa-slicer, super-slicer
    pkgs-talos.url = "github:nixos/nixpkgs/ee09932cedcef15aaf476f9343d1dea2cb77e261"; # talosctl, tflint, omnictl, signalbackup, kubelogin-oidc, kubectl-rook-ceph
    pkgs-vlc.url = "github:nixos/nixpkgs/41965737c1797c1d83cfb0b644ed0840a6220bd1";
    pkgs-apps.url = "github:nixos/nixpkgs/f665af0cdb70ed27e1bd8f9fdfecaf451260fc55"; # meld, butane
    pkgs-ceph.url = "github:nixos/nixpkgs/d1c15b7d5806069da59e819999d70e1cec0760bf";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-hardware,
      home-manager,
      pre-commit-hooks,
      nixvim,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
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

      homeConfigurations = {

        # Hostname: dualie (Debian Trixie)
        # Usage: 'nix run home-manager/master -- switch --flake .#groot@dualie'
        "groot@dualie" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          modules = [
            nixvim.homeModules.nixvim
            ./hosts/dualie/home.nix
          ];
          extraSpecialArgs = {
            inherit inputs;
          };
        };

        # Hostname: rk3588 (ARM64 SBC Fleet)
        # Usage: 'nix run home-manager/release-25.11 -- switch --flake .#groot@rk3588'
        "groot@rk3588" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."aarch64-linux";
          modules = [
            nixvim.homeModules.nixvim
            ./hosts/rk3588/home.nix
          ];
          extraSpecialArgs = {
            inherit inputs;
          };
        };

        # Hostname: forge (Debian 12)
        # Usage: 'nix run home-manager/release-25.11 -- switch --flake .#groot@forge'
        "groot@forge" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          modules = [
            nixvim.homeModules.nixvim
            ./hosts/forge/home.nix
          ];
          extraSpecialArgs = {
            inherit inputs;
          };
        };
      };

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
            ./hosts/sweet16/default.nix

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
                    nixvim.homeModules.nixvim
                    ./hosts/sweet16/home.nix
                  ];
                };
              };
            }
          ];
        };

        # Hostname: petunia
        petunia = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs;
          };
          modules = [
            # Disko declarative partitioning
            inputs.disko.nixosModules.disko

            # Hardware specific configuration
            nixos-hardware.nixosModules.common-cpu-amd
            nixos-hardware.nixosModules.common-gpu-nvidia
            nixos-hardware.nixosModules.common-pc-ssd

            # Main configuration entry point
            ./hosts/petunia/default.nix

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
                    nixvim.homeModules.nixvim
                    ./hosts/petunia/home.nix
                  ];
                };
              };
            }
          ];
        };

        # Hostname: avina (Proxmox LXC container — Matrix 2.0 public server)
        # Deploy: nixos-rebuild switch --flake .#avina (run inside the container)
        avina = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs;
          };
          modules = [
            # Main configuration entry point
            ./hosts/avina/default.nix

            # Stability Policy:
            # Pin the Matrix 2.0 stack to the current stable release cycle (25.11)
            # to ensure long-term reliability and spec compatibility.
            (
              { pkgs, ... }:
              {
                nixpkgs.overlays = [
                  (_final: _prev: {
                    inherit (inputs.pkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system})
                      matrix-synapse-unwrapped
                      matrix-authentication-service
                      livekit
                      lk-jwt-service
                      element-web
                      element-call
                      postgresql_16
                      ;
                  })
                ];
              }
            )

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
                    nixvim.homeModules.nixvim
                    ./hosts/avina/home.nix
                  ];
                };
              };
            }
          ];
        };

        # Hostname: openclaw (Proxmox LXC container)
        openclaw = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs;
          };
          modules = [
            # Main configuration entry point
            ./hosts/openclaw/default.nix

            # Unstable Packages Overlay
            (
              { pkgs, ... }:
              let
                unstable = import inputs.nixpkgs-unstable {
                  inherit (pkgs.stdenv.hostPlatform) system;
                  config.permittedInsecurePackages = [ "openclaw-2026.4.2" ];
                };
              in
              {
                nixpkgs.overlays = [
                  (_final: _prev: {
                    inherit (unstable) openclaw tailscale;
                  })
                ];
              }
            )

            # Home Manager configuration for groot
            home-manager.nixosModules.home-manager
            (
              { pkgs, ... }:
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  backupFileExtension = "bak";
                  extraSpecialArgs = {
                    inherit inputs;
                  };
                  users.groot = {
                    home.stateVersion = "25.11";
                    home.packages = with pkgs; [
                      openclaw
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
                      ./modules/user/bash.nix
                      ./modules/user/terminal-home.nix
                      ./modules/user/neovim-home.nix
                    ];
                  };
                };
              }
            )
          ];
        };

      };
    };
}
