_: {
  flake.modules.nixos.desktop-default = _: {
    # Desktop-specific kernel parameters.
    # quiet/splash provide a clean graphical boot experience on workstations.
    # mem_sleep_default is NOT set here — hardware profiles set it per-platform
    # (e.g. s2idle for Rembrandt, deep for Intel). Setting it here would override them.
    boot.kernelParams = [
      "quiet"
      "splash"
    ];
  };
}
