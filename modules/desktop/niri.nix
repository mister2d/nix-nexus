_: {
  flake.modules.nixos.desktop-niri =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nixpkgs.overlays = [
        (_final: prev: {
          # Globally disable tests for niri to prevent build failures in ISO/resource-constrained environments.
          niri = prev.niri.overrideAttrs (_old: {
            doCheck = false;
          });
        })
      ];

      # Niri Configuration
      # HEEDING THE WARNING: Using niri 25.11 from nixpkgs.
      programs.niri = {
        enable = true;
        # Force the package override to ensure tests are skipped system-wide.
        package = lib.mkForce (
          pkgs.niri.overrideAttrs (_old: {
            doCheck = false;
          })
        );
      };

      # Required for GTK/GNOME portal settings and DMS configuration
      programs.dconf.enable = true;

      # Systemd User Service Scoping
      systemd.user.services = {
        # DANK LINUX 1.4 DOCS FIX: Disable niri-flake's polkit agent.
        # The DMS built-in agent is the sole authentication authority.
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
