{ pkgs, ... }:

{
  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    drivers = [
      (pkgs.hplip.override { withPlugin = true; })
    ];
  };

  # Enable Avahi for network printer discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Declarative printer configuration
  hardware.printers = {
    ensurePrinters = [
      {
        name = "HP_ColorLaserJet_MFP_M283fdw";
        location = "Home Office";
        deviceUri = "ipp://hp-mfp.home.lan/ipp/print";
        model = "everywhere";
      }
    ];
    ensureDefaultPrinter = "HP_ColorLaserJet_MFP_M283fdw";
  };
}
