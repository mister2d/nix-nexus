{
  inputs,
  config,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;
  inherit (inputs)
    home-manager
    nixvim
    nixos-hardware
    ;
  inherit (inputs.self) overlays;
  inherit (config.flake.modules) nixos;
  hm = config.flake.modules.homeManager;
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
          hm.dualie-home
        ];
        extraSpecialArgs = {
          inherit (inputs) self;
          inherit inputs;
          homeManagerModules = hm;
        };
      };

      # Hostname: rk3588 (ARM64 SBC Fleet)
      # Usage: 'nix run home-manager/release-25.11 -- switch --flake .#groot@rk3588'
      "groot@rk3588" = home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages."aarch64-linux";
        modules = [
          nixvim.homeModules.nixvim
          hm.rk3588-home
        ];
        extraSpecialArgs = {
          inherit (inputs) self;
          inherit inputs;
          homeManagerModules = hm;
        };
      };

      # Hostname: forge (Debian 12)
      # Usage: 'nix run home-manager/release-25.11 -- switch --flake .#groot@forge'
      "groot@forge" = home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
        modules = [
          nixvim.homeModules.nixvim
          hm.forge-home
        ];
        extraSpecialArgs = {
          inherit (inputs) self;
          inherit inputs;
          homeManagerModules = hm;
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
          nixosModules = nixos;
        };
        modules = [
          (_: {
            nixpkgs.overlays = [ overlays.buildFixes ];
            nixpkgs.config.allowUnfree = true;
          })
          nixos-hardware.nixosModules.lenovo-thinkpad-z
          nixos-hardware.nixosModules.common-cpu-amd
          nixos-hardware.nixosModules.common-gpu-amd
          nixos-hardware.nixosModules.common-pc-ssd
          nixos.sweet16-default
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bak";
              extraSpecialArgs = {
                inherit (inputs) self;
                inherit inputs;
                homeManagerModules = hm;
              };
              users.ddukes = {
                imports = [
                  nixvim.homeModules.nixvim
                  hm.sweet16-home
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
          nixosModules = nixos;
        };
        modules = [
          (_: {
            nixpkgs.overlays = [ overlays.buildFixes ];
            nixpkgs.config.allowUnfree = true;
          })
          inputs.disko.nixosModules.disko
          nixos-hardware.nixosModules.common-cpu-amd
          nixos-hardware.nixosModules.common-gpu-amd
          nixos-hardware.nixosModules.common-pc-ssd
          inputs.rdna4-stack.nixosModules.rdna4-full
          nixos.petunia-default
          inputs.home-manager-unstable.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bak";
              extraSpecialArgs = {
                inherit (inputs) self;
                inherit inputs;
                homeManagerModules = hm;
              };
              users.ddukes = {
                imports = [
                  nixvim.homeModules.nixvim
                  hm.petunia-home
                ];
              };
            };
          }
        ];
      };

      # Hostname: avina (Proxmox LXC container — Matrix 2.0 public server)
      avina = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          inherit (inputs) self;
          nixosModules = nixos;
        };
        modules = [
          (_: {
            nixpkgs.overlays = [ overlays.buildFixes ];
            nixpkgs.config.allowUnfree = true;
          })
          nixos.avina-default
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
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bak";
              extraSpecialArgs = {
                inherit (inputs) self;
                inherit inputs;
                homeManagerModules = hm;
              };
              users.ddukes = {
                imports = [
                  nixvim.homeModules.nixvim
                  hm.avina-home
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
          nixosModules = nixos;
        };
        modules = [
          (_: {
            nixpkgs.overlays = [ overlays.buildFixes ];
            nixpkgs.config.allowUnfree = true;
          })
          nixos.openclaw-default
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
                    hm.user-bash
                    hm.user-terminal-home
                    hm.user-neovim-home
                    hm.openclaw-home
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
          nixosModules = nixos;
        };
        modules = [
          (_: {
            nixpkgs.overlays = [
              overlays.buildFixes
              overlays.mcp
            ];
            nixpkgs.config.allowUnfree = true;
          })
          nixos.hermes-default
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
                    hm.user-bash
                    hm.user-terminal-home
                    hm.user-neovim-home
                    hm.hermes-home
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
