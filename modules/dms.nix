{ inputs, ... }:
{
  # ============================================================================
  # Dank Material Shell (DMS) Aspect: Fluid Desktop Experience
  # ============================================================================

  den.aspects.dms-aspect = {
    nixos = { pkgs, lib, ... }:
      let
        unstable = import inputs.nixpkgs-unstable {
          inherit (pkgs.stdenv.hostPlatform) system;
          config.allowUnfree = true;
        };
      in
      {
        imports = [ inputs.dms.nixosModules.default ];

        programs.dank-material-shell = {
          enable = true;
          dgop.package = unstable.dgop;
          enableSystemMonitoring = true;
          enableVPN = true;
          enableDynamicTheming = true;
          enableAudioWavelength = true;
          enableCalendarEvents = true;
          enableClipboardPaste = true;
          systemd.enable = lib.mkDefault false;
        };

        environment.systemPackages = with pkgs; [
          unstable.dsearch
          unstable.xwayland-satellite
        ];

        # Home Manager Configuration for ddukes
        home-manager.users.ddukes = {
          imports = [
            inputs.dms.homeModules.default
            inputs.dms.homeModules.niri
          ];

          programs.dank-material-shell = {
            enable = true;
            dgop.package = unstable.dgop;
            niri = {
              includes.enable = false;
              enableSpawn = false;
              enableKeybinds = false;
            };
          };

          home.packages = with pkgs; [
            matugen
            cliphist
          ];
        };
      };
  };
}
