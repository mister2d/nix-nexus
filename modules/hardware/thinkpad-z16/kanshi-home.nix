_:

{
  # ThinkPad Z16 Specific Kanshi Display Profiles (Home Manager)
  # Manages display profiles and automatically switches when docking/undocking.
  services.kanshi = {
    enable = true;
    systemdTarget = "sway-session.target";

    settings = [
      {
        profile = {
          name = "undocked";
          outputs = [
            {
              criteria = "eDP-1";
              mode = "3840x2400";
              position = "0,0";
              scale = 1.15;
            }
          ];
          exec = [
            "echo 'Mobile' > /tmp/kanshi-profile"
            "pkill -RTMIN+8 waybar"
          ];
        };
      }
      {
        profile = {
          name = "docked";
          outputs = [
            {
              criteria = "eDP-1";
              mode = "3840x2400";
              position = "0,0";
              scale = 1.15;
            }
            {
              criteria = "DP-1";
              mode = "3440x1440";
              # Verified position from live 'swaymsg -t get_outputs'
              position = "3344,0";
              scale = 1.0;
            }
          ];
          exec = [
            "echo 'Docked' > /tmp/kanshi-profile"
            "pkill -RTMIN+8 waybar"
          ];
        };
      }
    ];
  };
}
