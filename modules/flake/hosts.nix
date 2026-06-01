{
  inputs,
  config,
  ...
}:
let
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

    };
  };
}
