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
        name = "HP_Color_LaserJet_MFP_M283fdw";
        location = "Home Office";
        deviceUri = "hp:/net/HP_Color_LaserJet_Pro_MFP_M282-M285?ip=10.0.5.10";
        model = "drv:///hp/hp-color_laserjet_mfp_m282-m285.ppd";
      }
    ];
    ensureDefaultPrinter = "HP_Color_LaserJet_MFP_M283fdw";
  };
}
