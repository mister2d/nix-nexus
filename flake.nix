{
  description = "Dendritic NixOS Configuration Framework";

  inputs = {
    # Official NixOS package source - Using 25.11 for 2026 stability
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Hardware quirks
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Home Manager - Standard for user-level config
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pin Google Chrome version (currently 145.0.7632.75)
    nixpkgs-chrome.url = "github:nixos/nixpkgs/fa56d7d6de78f5a7f997b0ea2bc6efd5868ad9e8";

    # EasyEffects Presets for superior laptop audio
    easyeffects-presets = {
      url = "github:JackHack96/easyeffects-presets";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixos-hardware, home-manager, nixpkgs-chrome, easyeffects-presets, ... }@inputs: {
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
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "bak";
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.ddukes = {
              imports = [
                ./modules/user/home.nix
                ./modules/hardware/thinkpad-z16/kanshi-home.nix
              ];
            };
          }
        ];
      };
    };
  };
}
