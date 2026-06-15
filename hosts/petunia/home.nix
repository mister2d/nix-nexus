_: {
  flake.modules.homeManager.petunia-home =
    { homeManagerModules, ... }:

    {
      imports = [
        homeManagerModules.user-home

        # Desktop Environments & Customization
        homeManagerModules.desktop-noctalia-home
        homeManagerModules.hardware-petunia-hypr-home
        homeManagerModules.desktop-hyprland-home
      ];

      # Resource Monitor (amdgpu_top provides detailed AMD metrics; btop for process view)
      programs.btop.enable = true;
    };
}
