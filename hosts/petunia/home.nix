{ homeManagerModules, ... }:

{
  imports = [
    homeManagerModules.user-home

    # Desktop Environments & Customization
    homeManagerModules.desktop-sway-home
    homeManagerModules.desktop-waybar-home
    homeManagerModules.desktop-notifications
  ];

  # Resource Monitor (amdgpu_top provides detailed AMD metrics; btop for process view)
  programs.btop.enable = true;

  # Petunia specific home-manager settings
  # (e.g., custom monitor layouts in kanshi)
}
