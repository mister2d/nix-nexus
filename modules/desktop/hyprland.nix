# Registry key: flake.modules.nixos.desktop-hyprland
# Configures: the Hyprland compositor and gamemode policy.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.desktop-hyprland =
    {
      lib,
      pkgs,
      inputs,
      ...
    }:
    let
      pin = import ../../lib/pinned-pkgs.nix { inherit pkgs; };
      unstablePkgs = pin.pinned inputs.nixpkgs-unstable;
    in
    {
      # Both hosts need Hyprland >= 0.56 for render.cm_auto_hdr and related
      # HDR/color-management settings. nixos-26.05 ships 0.55.4, which lacks
      # them, so both packages come from nixpkgs-unstable regardless of which
      # nixpkgs channel the host's system builds from.
      programs.hyprland = {
        enable = true;
        package = lib.mkDefault unstablePkgs.hyprland;
        portalPackage = lib.mkDefault unstablePkgs.xdg-desktop-portal-hyprland;
        withUWSM = false;
        xwayland.enable = true;
        systemd.setPath.enable = false;
      };

      # PAM service required for hyprlock GPU-accelerated lockscreen.
      security.pam.services.hyprlock = { };

      # polkit — defensive mkDefault. desktop-niri also sets this on sweet16.
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
            # sweet16 has no card0. dGPU (RX 6700M) is card1.
            gpu_device = 1;
          };
        };
      };

      environment.systemPackages = with pkgs; [
        hyprutils
      ];
    };
}
