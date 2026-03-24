{ lib, config, ... }:
{
  options.nix-nexus.virtualization.guestAgent.enable =
    lib.mkEnableOption "QEMU Guest Agent and VM optimizations";

  config = lib.mkIf config.nix-nexus.virtualization.guestAgent.enable {
    services.qemuGuest.enable = true;

    # Serial Console:
    # tty0 keeps Proxmox VNC output alive; ttyS0 is the primary console
    # (last listed) so kernel messages, panics, and systemd output all reach
    # the serial port. Baud rate must match the Proxmox serial socket config.
    boot.kernelParams = [
      "console=tty0"
      "console=ttyS0,115200n8"
    ];

    # Serial Login:
    # Provides an interactive login prompt over the serial port so the
    # operator can authenticate without VNC or SSH.
    systemd.services."serial-getty@ttyS0" = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Restart = "always";
    };

    # Ensure the system doesn't hang on shutdown if the agent is slow to respond
    systemd.services.qemu-guest-agent.serviceConfig.TimeoutStopSec = "20s";
  };
}
