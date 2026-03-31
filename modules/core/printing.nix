{ pkgs, ... }:

{
  # Core Printing and Discovery Stack
  # This module provides a stateless, declarative printing environment powered by CUPS.
  # It leverages Avahi for network-wide printer discovery and provides intuitive
  # systemd aliases for standard administrative operations.

  services = {
    # CUPS Printing Service
    printing = {
      enable = true;
      browsing = true;
      logLevel = "debug";

      # Enforcement of a stateless configuration prevents manual drift and ensures
      # the printer environment is reset to the declarative baseline on every boot.
      stateless = true;

      drivers = [
        (pkgs.hplip.override { withPlugin = true; })
      ];

      # Network discovery for shared printers
      browsed.enable = true;
    };

    # Zero-Configuration Networking (mDNS/DNS-SD)
    # Required for resolving .local printer addresses and automated discovery.
    avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
      openFirewall = true;
    };
  };

  # Systemd Service Abstractions
  # These aliases provide human-readable entry points for managing the printing stack.
  systemd.services = {
    cups.aliases = [ "printing.service" ];
    ensure-printers = {
      aliases = [ "printing-provision.service" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };
  };

  # Declarative Printer Inventory
  hardware.printers = {
    ensurePrinters = [
      {
        # Primary Office Printer
        name = "hp-m283fdw";
        description = "HP Color LaserJet MFP M283fdw";
        location = "Home Office";
        deviceUri = "ipp://hp-mfp.home.lan/ipp/print";
        model = "everywhere";
      }
    ];
    ensureDefaultPrinter = "hp-m283fdw";
  };
}
