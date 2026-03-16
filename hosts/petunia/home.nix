{ ... }:

{
  imports = [
    ../../modules/user/home.nix
    ../../modules/user/dev-home.nix
    ../../modules/user/terminal-home.nix
    ../../modules/user/neovim-home.nix
    ../../modules/user/television-home.nix

    # Desktop Environments & Customization
    ../../modules/desktop/niri-home.nix
    ../../modules/desktop/sway-home.nix
    ../../modules/desktop/waybar-home.nix

    # Petunia-specific hardware optimizations for desktop sessions
    ../../modules/hardware/petunia/niri-hardware-home.nix
  ];

  # Petunia specific home-manager settings
  # (e.g., custom monitor layouts in kanshi)
}
