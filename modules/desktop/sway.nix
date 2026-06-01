_: {
  flake.modules.nixos.desktop-sway =
    { pkgs, ... }:
    {
      # System-wide Sway/Wayland support
      programs.sway = {
        enable = true;
        wrapperFeatures.gtk = true;
        extraPackages = with pkgs; [
          # Base essentials for the system to boot to desktop
          swaylock
          swayidle
          foot
          wofi
          kanshi
        ];
      };

      # System-wide Touchpad/Keyboard fixes
      environment.etc."sway/config.d/touchpad.conf".text = ''
        input "type:touchpad" {
            tap enabled
            natural_scroll enabled
            click_method clickfinger
        }
      '';
    };
}
