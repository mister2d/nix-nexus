_: {
  flake.modules.homeManager.sweet16-home =
    { pkgs, homeManagerModules, ... }:

    {
      # ThinkPad Z16 (sweet16) Host-Specific Home Manager Profile
      # This profile merges shared user settings with hardware-specific optimizations
      # for the OLED display, haptic touchpad, and docking behavior.
      imports = [
        homeManagerModules.user-home
        homeManagerModules.hardware-z16-kanshi-home
        homeManagerModules.hardware-z16-niri-home

        # NNN stack: Niri compositor + Noctalia v5 shell
        homeManagerModules.desktop-noctalia-home
      ];

      # Resource Monitor with AMD GPU support
      programs.btop.package = pkgs.btop.override { rocmSupport = true; };
    };
}
