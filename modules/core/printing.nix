_: {
  flake.modules.nixos.core-printing =
    { pkgs, ... }:
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

      systemd.services = {
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
            ExecStartPre = "${pkgs.writeShellScript "wait-for-printer-dns" ''
              for i in $(seq 1 30); do
                ${pkgs.glibc.bin}/bin/getent hosts hp-mfp.home.lan > /dev/null 2>&1 && exit 0
                sleep 2
              done
              echo "hp-mfp.home.lan not resolvable after 60s"
              exit 1
            ''}";
            Restart = "on-failure";
            RestartSec = 30;
          };
        };
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
}
