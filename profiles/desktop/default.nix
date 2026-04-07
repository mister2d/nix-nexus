{ ... }:

{
  imports = [
    ../../modules/desktop/greetd.nix
    ../../modules/desktop/wayland.nix
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/theme.nix
  ];

  # Desktop-specific kernel parameters.
  # quiet/splash provide a clean graphical boot experience on workstations.
  # mem_sleep_default=deep prefers S3 suspend over s2idle on AMD/Intel laptops.
  # These are intentionally absent from modules/core/boot.nix — server and
  # SBC hosts must not inherit desktop boot behaviour.
  boot.kernelParams = [
    "quiet"
    "splash"
    "mem_sleep_default=deep"
  ];
}
