{ pkgs, ... }:

{
  imports = [
    ../../modules/user/home.nix
    ../../modules/user/dev-home.nix
    ../../modules/user/terminal-home.nix
    ../../modules/user/neovim-home.nix
    ../../modules/user/television-home.nix

    # Desktop Environments & Customization
    ../../modules/desktop/sway-home.nix
    ../../modules/desktop/waybar-home.nix
    ../../modules/desktop/notifications.nix
  ];

  # Resource Monitor (amdgpu_top provides detailed AMD metrics; btop for process view)
  programs.btop.enable = true;

  # Petunia specific home-manager settings
  # (e.g., custom monitor layouts in kanshi)
}
