{ inputs, ... }:
{
  # ============================================================================
  # Base Aspect: The Foundation of the Organism
  # ============================================================================

  den.aspects.base-aspect = {
    nixos = { config, pkgs, lib, ... }: {
      nixpkgs.config.allowUnfree = true;
      imports = [
        inputs.home-manager.nixosModules.home-manager
      ];

      system.stateVersion = lib.mkDefault "25.11";
      time.timeZone = "America/New_York";
      i18n.defaultLocale = "en_US.UTF-8";

      # Standard user across the entire fleet
      users.users.ddukes = {
        isNormalUser = true;
        description = "ddukes";
        password = "nixos";
        extraGroups = [
          "networkmanager"
          "wheel"
          "video"
          "audio"
          "input"
          "docker"
          "fuse"
          "render"
        ];
        shell = pkgs.bash;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQp6H/n2JPSt1VxCAupTC1OTh7R3eu7wO0ZtCNbAkd7"
        ];
      };

      # Fleet-wide packages
      environment.systemPackages = with pkgs; [
        vim
        git
        curl
        wget
        htop
        tree
        earlyoom
      ];

      # System Stability & Memory Pressure
      boot.kernel.sysctl = lib.mkIf (!config.boot.isContainer) {
        "vm.swappiness" = 10;
        "vm.vfs_cache_pressure" = 50;
        "vm.min_free_kbytes" = 262144;
      };

      services.earlyoom = {
        enable = true;
        freeMemThreshold = 5;
        freeSwapThreshold = 10;
      };

      # Home Manager Configuration for ddukes
      home-manager.users.ddukes = {
        home.stateVersion = "25.11";
        programs.home-manager.enable = true;
      };
    };
  };
}
