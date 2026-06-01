_: {
  flake.modules.nixos.desktop-greetd =
    { pkgs, ... }:
    {
      # Display Manager (Greetd)
      # Centralized configuration using tuigreet for multi-compositor selection.
      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            # Using tuigreet without a fixed --cmd flag to allow selecting from
            # available sessions (e.g. Sway, Niri) discovered in the system.
            # --remember ensures the last selected session is highlighted.
            command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks";
            user = "greeter";
          };
        };
      };

      # Required system packages for greetd
      environment.systemPackages = with pkgs; [
        tuigreet
      ];
    };
}
