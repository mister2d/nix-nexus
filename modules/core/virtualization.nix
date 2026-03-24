{ lib, ... }:
{
  options.nix-nexus.virtualization.guestAgent.enable =
    lib.mkEnableOption "QEMU Guest Agent and VM optimizations";

  config =
    lib.mkIf
      (lib.attrByPath [ "nix-nexus" "virtualization" "guestAgent" "enable" ] false {
        inherit (lib) nix-nexus;
      })
      {
        services.qemuGuest.enable = true;

        # VM-specific performance and reliability tunings
        boot.kernelParams = [ "console=ttyS0" ];

        # Ensure the system doesn't hang on shutdown if the agent is slow to respond
        systemd.services.qemu-guest-agent.serviceConfig.TimeoutStopSec = "20s";
      };
}
