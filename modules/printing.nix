{
  lib,
  ...
}:
{

  den.aspects.printing-aspect = lib.mkForce {
    nixos =
      { pkgs, ... }:
      {
        services = {
          printing = {
            enable = true;
            browsing = true;
            stateless = true;
            drivers = [ (pkgs.hplip.override { withPlugin = true; }) ];
            browsed.enable = true;
          };
          avahi = {
            enable = true;
            nssmdns4 = true;
            nssmdns6 = true;
            openFirewall = true;
          };
        };

        systemd.services.cups.aliases = [ "printing.service" ];
        systemd.services.ensure-printers = {
          aliases = [ "printing-provision.service" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
        };

        hardware.printers = {
          ensurePrinters = [
            {
              name = "hp-m283fdw";
              description = "HP Color LaserJet MFP M283fdw";
              location = "Home Office";
              deviceUri = "ipp://hp-mfp.home.lan/ipp/print";
              model = "everywhere";
            }
          ];
          ensureDefaultPrinter = "hp-m283fdw";
        };
      };
  };
}
