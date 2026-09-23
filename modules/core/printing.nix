# Registry key: flake.modules.nixos.core-printing
# Configures: CUPS printing, Avahi discovery, and the ensured HP printer.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
# Printer provisioning runs in systemd.services.cups (ExecStartPost) on
# nixpkgs 26.11+ (sweet16 tracks 26.05 and still runs it in a separate
# ensure-printers.service). Each host's own nixosSystem lib decides which
# branch applies, since sweet16 and petunia build against different
# nixpkgs inputs.
_: {
  flake.modules.nixos.core-printing =
    { lib, pkgs, ... }:
    let
      newProvisioning = lib.versionAtLeast lib.trivial.release "26.11";
    in
    {
      services = {
        printing = {
          enable = true;
          browsing = true;
          logLevel = "debug";
          stateless = true;

          drivers = [
            (pkgs.hplip.override { withPlugin = true; })
          ];

          browsed.enable = true;
        };

        avahi = {
          enable = true;
          nssmdns4 = true;
          nssmdns6 = true;
          openFirewall = true;
        };
      };

      systemd.services = lib.mkMerge [
        (lib.mkIf (!newProvisioning) {
          cups.aliases = [ "printing.service" ];
          ensure-printers = {
            aliases = [ "printing-provision.service" ];
            after = [
              "network-online.target"
              "cups.service"
              "avahi-daemon.service"
              "nss-lookup.target"
            ];
            wants = [
              "network-online.target"
              "cups.service"
              "avahi-daemon.service"
              "nss-lookup.target"
            ];
            serviceConfig = {
              Restart = "on-failure";
              RestartSec = 30;
            };
          };
        })
        (lib.mkIf newProvisioning {
          cups = {
            aliases = [ "printing.service" ];
            after = [
              "network-online.target"
              "avahi-daemon.service"
              "nss-lookup.target"
            ];
            wants = [
              "network-online.target"
              "avahi-daemon.service"
              "nss-lookup.target"
            ];
            serviceConfig = {
              Restart = "on-failure";
              RestartSec = 30;
            };
          };
        })
      ];

      hardware.printers = {
        ensurePrinters = [
          {
            name = "hp-m283fdw";
            description = "HP Color LaserJet MFP M283fdw";
            location = "Home Office";
            deviceUri = "ipp://10.0.5.10/ipp/print";
            model = "everywhere";
          }
        ];
        ensureDefaultPrinter = "hp-m283fdw";
      };
    };
}
