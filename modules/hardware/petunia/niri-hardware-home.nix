_: {
  flake.modules.homeManager.hardware-petunia-niri-home = _: {
    # Petunia-specific Niri Hardware Configuration (Home Manager)
    # Optimized for RTX 3080 output.

    programs.niri.settings = {
      # High-performance output settings for desktop displays
      outputs = {
        # Placeholder for primary monitor - user should adjust via niri msg or recon
        "DP-1" = {
          mode = {
            width = 2560;
            height = 1440;
            refresh = 144.0;
          };
          variable-refresh-rate = true;
        };
      };

      # Input settings for desktop peripherals
      input = {
        mouse = {
          accel-speed = 0.0;
          accel-profile = "flat";
        };

        keyboard = {
          xkb.layout = "us";
        };
      };
    };
  };
}
