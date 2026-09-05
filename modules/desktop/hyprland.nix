# Registry key: flake.modules.nixos.desktop-hyprland
# Configures: the Hyprland compositor, its binary cache, and gamemode policy.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.desktop-hyprland =
    {
      lib,
      pkgs,
      inputs,
      ...
    }:
    {
      imports = [
        # Override programs.hyprland.{package,portalPackage} defaults to the
        # upstream flake outputs (v0.56.1). nixpkgs module still provides all
        # option declarations, session entry, polkit, portal, systemd PATH.
        inputs.hyprland.nixosModules.default
      ];

      # Upstream Hyprland binary cache. Declared in nix.settings so it applies
      # to non-interactive deploys; a flake nixConfig entry would require
      # per-user acceptance that ssh sessions cannot prompt for, and Hyprland
      # would build from source on the host.
      nix.settings = {
        substituters = lib.mkAfter [ "https://hyprland.cachix.org" ];
        trusted-public-keys = lib.mkAfter [
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        ];
      };

      programs.hyprland = {
        enable = true;
        withUWSM = false;
        xwayland.enable = true;
        systemd.setPath.enable = false;
      };

      # PAM service required for hyprlock GPU-accelerated lockscreen.
      security.pam.services.hyprlock = { };

      # polkit — defensive mkDefault; desktop-niri also sets this on sweet16.
      security.polkit.enable = lib.mkDefault true;

      # hardware-z16 overrides power-profiles-daemon and upower at normal
      # priority, so both stay mkDefault here to let it win on that host.
      services = {
        # power-profiles-daemon: needed for gamemode CPU governor switching.
        power-profiles-daemon.enable = lib.mkDefault true;
        upower.enable = lib.mkDefault true;
        accounts-daemon.enable = lib.mkDefault true;
      };

      # gamemode: CPU governor switching on game launch/exit.
      programs.gamemode = {
        enable = lib.mkDefault true;
        settings = {
          general = {
            reaper_freq = 5;
            desiredgov = "performance";
            softrealtime = "auto";
            inhibit_screensaver = 0;
          };
          gpu = {
            apply_gpu_optimisations = "accept-responsibility";
            # sweet16 has no card0; dGPU (RX 6700M) is card1.
            gpu_device = 1;
          };
        };
      };

      environment.systemPackages = with pkgs; [
        hyprutils
      ];
    };
}
