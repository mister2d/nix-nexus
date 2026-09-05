# Merged into: flake.modules.nixos.hardware-z16
# Configures: Bluetooth power-on-boot and the blueman applet.
# Imported by: hosts/sweet16/default.nix (sweet16-default).
_: {
  flake.modules.nixos.hardware-z16 = _: {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
        };
      };
    };

    services.blueman.enable = true;
  };
}
