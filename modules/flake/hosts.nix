{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  inherit (inputs)
    home-manager
    nixvim
    nixos-hardware
    ;
  # Reference our own overlays via inputs.self
  inherit (inputs.self) overlays;
in
{
  flake = {
    homeConfigurations = {
      # Hostname: dualie (Debian Trixie)
      # Usage: 'nix run home-manager/master -- switch --flake .#groot@dualie'
      "groot@dualie" = home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
        modules = [
          nixvim.homeModules.nixvim
          ../../hosts/dualie/home.nix
        ];
        extraSpecialArgs = {
          inherit (inputs) self;
          inherit inputs;
        };
      };

      # Hostname: rk3588 (ARM64 SBC Fleet)
      # Usage: 'nix run home-manager/release-25.11 -- switch --flake .#groot@rk3588'
      "groot@rk3588" = home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages."aarch64-linux";
        modules = [
          nixvim.homeModules.nixvim
          ../../hosts/rk3588/home.nix
        ];
        extraSpecialArgs = {
          inherit (inputs) self;
          inherit inputs;
        };
      };

      # Hostname: forge (Debian 12)
      # Usage: 'nix run home-manager/release-25.11 -- switch --flake .#groot@forge'
      "groot@forge" = home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
        modules = [
          nixvim.homeModules.nixvim
          ../../hosts/forge/home.nix
        ];
        extraSpecialArgs = {
          inherit (inputs) self;
          inherit inputs;
        };
      };
    };

    nixosConfigurations = {
      # Hostname: sweet16
      sweet16 = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          inherit (inputs) self;
        };
        modules = [
          # Global build fixes
          (_: {
            nixpkgs.overlays = [ overlays.buildFixes ];
            nixpkgs.config.allowUnfree = true;
          })

          # Hardware specific configuration
          nixos-hardware.nixosModules.lenovo-thinkpad-z
          nixos-hardware.nixosModules.common-cpu-amd
          nixos-hardware.nixosModules.common-gpu-amd
          nixos-hardware.nixosModules.common-pc-ssd

          # Main configuration entry point
          ../../hosts/sweet16/default.nix

          # Home Manager configuration
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bak";
              extraSpecialArgs = {
                inherit (inputs) self;
                inherit inputs;
              };
              users.ddukes = {
                imports = [
                  nixvim.homeModules.nixvim
                  ../../hosts/sweet16/home.nix
                ];
              };
            };
          }
        ];
      };

      # Hostname: petunia
      petunia = inputs.nixpkgs-unstable.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          inherit (inputs) self;
        };
        modules = [
          # Global build fixes
          (_: {
            nixpkgs.overlays = [ overlays.buildFixes ];
            nixpkgs.config.allowUnfree = true;
          })

          # Disko declarative partitioning
          inputs.disko.nixosModules.disko

          # Hardware specific configuration
          nixos-hardware.nixosModules.common-cpu-amd
          nixos-hardware.nixosModules.common-gpu-amd
          nixos-hardware.nixosModules.common-pc-ssd

          # RDNA4 GPU stack (Vulkan + ROCm 7.x + LACT + llama.cpp build env)
          inputs.rdna4-stack.nixosModules.rdna4-full

          # Main configuration entry point
          ../../hosts/petunia/default.nix

          # Home Manager configuration (tracks nixpkgs-unstable to match host channel)
          inputs.home-manager-unstable.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bak";
              extraSpecialArgs = {
                inherit (inputs) self;
                inherit inputs;
              };
              users.ddukes = {
                imports = [
                  nixvim.homeModules.nixvim
                  ../../hosts/petunia/home.nix
                ];
              };
            };
          }
        ];
      };

      # Hostname: avina (Proxmox LXC container — Matrix 2.0 public server)
      # Deploy: nixos-rebuild switch --flake .#avina (run inside the container)
      avina = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          inherit (inputs) self;
        };
        modules = [
          # Global build fixes
          (_: {
            nixpkgs.overlays = [ overlays.buildFixes ];
            nixpkgs.config.allowUnfree = true;
          })

          # Main configuration entry point
          ../../hosts/avina/default.nix

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
                inherit (inputs) self;
                inherit inputs;
              };
              users.ddukes = {
                imports = [
                  nixvim.homeModules.nixvim
                  ../../hosts/avina/home.nix
                ];
              };
            };
          }
        ];
      };

      # Hostname: openclaw (Proxmox LXC container)
      openclaw = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          inherit (inputs) self;
        };
        modules = [
          # Global build fixes
          (_: {
            nixpkgs.overlays = [ overlays.buildFixes ];
            nixpkgs.config.allowUnfree = true;
          })

          # Main configuration entry point
          ../../hosts/openclaw/default.nix

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
                    ../../modules/user/bash.nix
                    ../../modules/user/terminal-home.nix
                    ../../modules/user/neovim-home.nix
                    ../../hosts/openclaw/home.nix
                  ];
                };
              };
            }
          )
        ];
      };

      # Hostname: hermes (Proxmox LXC container — Hermes AI Agent)
      hermes = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          inherit (inputs) self;
        };
        modules = [
          # Global build fixes + MCP server packages overlay
          (_: {
            nixpkgs.overlays = [
              overlays.buildFixes
              overlays.mcp
            ];
            nixpkgs.config.allowUnfree = true;
          })

          # Main configuration entry point
          ../../hosts/hermes/default.nix

          # Host-scoped overlay: make llm-agents packages available
          (
            { pkgs, ... }:
            let
              agentPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
            in
            {
              nixpkgs.overlays = [
                (_final: _prev: {
                  llm-agents = agentPkgs // {
                    hermes-agent = agentPkgs.hermes-agent.overridePythonAttrs (old: {
                      makeWrapperArgs = (old.makeWrapperArgs or [ ]) ++ [
                        "--set"
                        "PYTHONPATH"
                        (lib.makeSearchPath "lib/python3.13/site-packages" (old.propagatedBuildInputs or [ ]))
                      ];
                    });
                  };
                })
              ];
            }
          )

          # Home Manager configuration for groot
          home-manager.nixosModules.home-manager
          (
            { pkgs, ... }:
            let
              unstablePkgs = import inputs.nixpkgs-unstable {
                inherit (pkgs.stdenv.hostPlatform) system;
                config.allowUnfree = true;
                overlays = [ overlays.buildFixes ];
              };
            in
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
                    llm-agents.hermes-agent
                    nodejs_24
                    python314
                    uv
                    git
                    btop
                    htop
                    openssl

                    # MCP servers (mirrors dev-home.nix mcpPackages)
                    context7-mcp
                    github-mcp-server
                    unstablePkgs.mcp-nixos
                    mcp-server-time
                    terraform-mcp-server
                  ];
                  imports = [
                    inputs.nixvim.homeModules.nixvim
                    ../../modules/user/bash.nix
                    ../../modules/user/terminal-home.nix
                    ../../modules/user/neovim-home.nix
                    ../../hosts/hermes/home.nix
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
