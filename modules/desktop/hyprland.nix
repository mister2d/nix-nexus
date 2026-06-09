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
        # upstream flake outputs (v0.55.3). nixpkgs module still provides all
        # option declarations, session entry, polkit, portal, systemd PATH.
        inputs.hyprland.nixosModules.default
      ];

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
          };
        };
      };

      # EasyEffects service scoping: start after the graphical session is
      # established so PipeWire is ready; tie lifecycle to the session.
      systemd.user.services.easyeffects = {
        after = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
      };

      environment.systemPackages = with pkgs; [
        hyprutils
      ];
    };
}
