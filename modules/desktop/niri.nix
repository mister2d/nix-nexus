_: {
  flake.modules.nixos.desktop-niri =
    {
      pkgs,
      lib,
      inputs,
      ...
    }:
    {
      nixpkgs.overlays = [
        (_final: prev: {
          niri = inputs.pkgs-niri.legacyPackages.${prev.stdenv.hostPlatform.system}.niri.overrideAttrs (_: {
            doCheck = false;
          });
        })
      ];

      programs.niri = {
        enable = true;
        package = lib.mkForce (
          inputs.pkgs-niri.legacyPackages.${pkgs.stdenv.hostPlatform.system}.niri.overrideAttrs (_: {
            doCheck = false;
          })
        );
      };

      # Required for GTK/GNOME portal settings and DMS configuration
      programs.dconf.enable = true;

      # Systemd User Service Scoping
      systemd.user.services = {
        # The shell's built-in agent is the sole authentication authority.
        niri-flake-polkit.enable = false;

        # Generic service scoping for background daemons
        easyeffects = {
          # Remove wantedBy to prevent early startup failure before environment sync.
          # The niri-home.nix spawn-at-startup block will restart it once ready.
          after = [ "graphical-session.target" ];
          partOf = [ "graphical-session.target" ];
        };
      };

      # Graphics and Hardware optimizations (Generic)
      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          rocmPackages.clr.icd # OpenCL for AMD
        ];
      };

      security.polkit.enable = true;

      # Essential System Services
      services = {
        accounts-daemon.enable = true;
        upower.enable = true;
      };
    };
}
