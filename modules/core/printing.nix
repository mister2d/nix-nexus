# Registry key: flake.modules.nixos.core-printing
# Configures: CUPS printing, Avahi discovery, and the ensured HP printer.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
# The queue points at the Nomad-hosted CUPS print server
# (ipp://print-server.service.consul:631), which spools jobs even while the
# physical printer is off. Printer provisioning uses nixpkgs' own mechanism:
# systemd.services.cups (ExecStartPost) on nixpkgs 26.11+ (petunia), and a
# separate ensure-printers.service on nixpkgs 26.05 (sweet16). Both units wait
# for network-online.target and retry every 10s for about a minute, so the
# Consul DNS name can resolve late in boot.
_: {
  flake.modules.nixos.core-printing =
    {
      config,
      lib,
      pkgs,
      ...
    }:
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

      systemd.services =
        let
          retryUntilOnline = {
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            startLimitIntervalSec = 120;
            startLimitBurst = 10;
            serviceConfig.RestartSec = 10;
          };
        in
        {
          cups = retryUntilOnline // {
            aliases = [ "printing.service" ];
          };
        }
        // lib.optionalAttrs (lib.versionOlder config.system.nixos.release "26.11") {
          ensure-printers = retryUntilOnline // {
            serviceConfig = retryUntilOnline.serviceConfig // {
              Restart = "on-failure";
            };
          };
        };

      hardware.printers = {
        ensurePrinters = [
          {
            name = "hp-m283fdw";
            description = "HP Color LaserJet MFP M283fdw";
            location = "Home Office";
            deviceUri = "ipp://print-server.service.consul:631/printers/hp-m283fdw";
            model = "everywhere";
          }
        ];
        ensureDefaultPrinter = "hp-m283fdw";
      };
    };
}
