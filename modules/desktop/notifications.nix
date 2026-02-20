{ pkgs, lib, ... }:

{
  services.dunst = {
    enable = true;
    settings = {
      global = {
        width = 300;
        height = 300;
        offset = "30x30";
        origin = "top-right";
        transparency = 0;
        padding = 16;
        horizontal_padding = 16;
        frame_width = 2;
        frame_color = "#00FFFF";
        separator_color = "frame";
        font = "JetBrainsMono Nerd Font 10";
        line_height = 4;
        idle_threshold = 120;
        alignment = "left";
        show_age_threshold = 60;
        word_wrap = "yes";
        ignore_newline = "no";
        stack_duplicates = true;
        hide_duplicate_count = false;
        show_indicators = "yes";
        icon_position = "left";
        max_icon_size = 32;
        sticky_history = "yes";
        history_length = 20;
        browser = "${pkgs.google-chrome}/bin/google-chrome-stable";
        always_run_script = true;
        title = "Dunst";
        class = "Dunst";
        corner_radius = 0;
      };

      urgency_low = {
        background = "#000000";
        foreground = "#FFFFFF";
        timeout = 10;
      };

      urgency_normal = {
        background = "#000000";
        foreground = "#FFFFFF";
        timeout = 10;
      };

      urgency_critical = {
        background = "#000000";
        foreground = "#FFFFFF";
        frame_color = "#FF00FF";
        timeout = 0;
      };
    };
  };

  # Ensure Dunst only starts during Sway sessions
  systemd.user.services.dunst.Unit.PartOf = lib.mkForce [ "sway-session.target" ];
  systemd.user.services.dunst.Install.WantedBy = lib.mkForce [ "sway-session.target" ];
}
