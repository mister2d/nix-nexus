{ inputs, ... }:
{
  # ============================================================================
  # Niri Aspect: Scrollable-Tiling Visuals
  # ============================================================================

  den.aspects.niri-aspect = {
    nixos = { pkgs, lib, ... }: {
      # imports = [ inputs.niri.nixosModules.niri ];

      nixpkgs.overlays = [
        (_final: prev: {
          niri = prev.niri.overrideAttrs (_old: { doCheck = false; });
        })
      ];

      programs.niri.enable = true;

      programs.dconf.enable = true;

      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [ rocmPackages.clr.icd ];
      };

      environment.systemPackages = with pkgs; [ qt6.qtwayland kdePackages.qtwayland ];

      # Home Manager Configuration for ddukes
      home-manager.users.ddukes = {
        imports = [ inputs.niri.homeModules.niri ];
        programs.niri.enable = true;
        programs.niri.settings = {
          input = {
            keyboard.xkb.layout = "us";
            touchpad = { tap = true; natural-scroll = true; dwt = true; };
            focus-follows-mouse.enable = true;
          };
          xwayland-satellite.enable = true;
          layout = {
            gaps = 8.0;
            focus-ring = { enable = true; width = 3.0; active.color = "rgba(100, 100, 100, 0.7)"; };
          };
          binds = {
            "Mod+Return".action.spawn = [ "${pkgs.kitty}/bin/kitty" ];
            "Mod+Q".action.close-window = { };
            "Mod+Shift+E".action.quit = { };
          };
        };
      };
    };
  };
}
