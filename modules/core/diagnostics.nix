# Registry key: flake.modules.nixos.core-diagnostics
# Configures: crash diagnostics (sysrq, panic-on-lockup, auto-reboot) and journald sync interval.
# Imported by: hosts/sweet16/default.nix (sweet16-default).
_: {
  flake.modules.nixos.core-diagnostics = _: {
    boot.kernel.sysctl = {
      "kernel.sysrq" = 1;
      "kernel.softlockup_panic" = 1;
      "kernel.hung_task_panic" = 1;
      "kernel.hung_task_timeout_secs" = 120;
      "kernel.panic" = 10;
    };

    services.journald.extraConfig = "SyncIntervalSec=5s";
  };
}
