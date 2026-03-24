{ lib, config, ... }:
{
  options.nix-nexus.virtualization.guestAgent.enable =
    lib.mkEnableOption "QEMU Guest Agent and VM optimizations";

  config = lib.mkIf config.nix-nexus.virtualization.guestAgent.enable {
    services.qemuGuest.enable = true;

    # VM-specific performance and reliability tunings
    boot.kernelParams = [ "console=ttyS0" ];

    # Ensure the system doesn't hang on shutdown if the agent is slow to respond
    systemd.services.qemu-guest-agent.serviceConfig.TimeoutStopSec = "20s";
  };
}
