_: {
  flake.modules.nixos.core-virtualization =
    { lib, config, ... }:
    {
      options.nix-nexus.virtualization.guestAgent.enable =
        lib.mkEnableOption "QEMU Guest Agent and VM optimizations";

      config = lib.mkIf config.nix-nexus.virtualization.guestAgent.enable {
        services.qemuGuest.enable = true;

        # tty0 keeps Proxmox VNC output alive; ttyS0 is the primary console
        # so kernel messages and systemd output reach the serial port.
        boot.kernelParams = [
          "console=tty0"
          "console=ttyS0,115200n8"
        ];

        systemd.services."serial-getty@ttyS0" = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Restart = "always";
        };

        systemd.services.qemu-guest-agent.serviceConfig.TimeoutStopSec = "20s";
      };
    };
}
