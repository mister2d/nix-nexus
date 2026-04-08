{ ... }:
{
  # ============================================================================
  # Core Utility Aspects
  # ============================================================================

  den.aspects.ceph-aspect = {
    nixos = { pkgs, ... }: {
      systemd.services.ceph-mount-teardown = {
        description = "Unmount CephFS volumes before sleep, suspend, or shutdown";
        before = [ "sleep.target" "suspend.target" "shutdown.target" "network-pre.target" "NetworkManager.service" ];
        wantedBy = [ "sleep.target" "suspend.target" "shutdown.target" ];
        serviceConfig = {
          Type = "oneshot";
          User = "ddukes";
          Environment = [ "HOME=/home/ddukes" "XDG_RUNTIME_DIR=/run/user/1000" ];
          TimeoutStartSec = "15s";
          ExecStart = "${pkgs.bash}/bin/bash -c 'SCRIPT_PATH=\"/etc/profiles/per-user/ddukes/bin/ceph_mount_ctl\"; if [[ -x \"$SCRIPT_PATH\" ]]; then for alias in $(\"$SCRIPT_PATH\" list); do \"$SCRIPT_PATH\" unmount \"$alias\"; done; fi'";
        };
      };
    };
  };

  den.aspects.printing-aspect = {
    nixos = { pkgs, ... }: {
      services.printing = {
        enable = true;
        browsing = true;
        logLevel = "debug";
        stateless = true;
        drivers = [ (pkgs.hplip.override { withPlugin = true; }) ];
        browsed.enable = true;
      };
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        nssmdns6 = true;
        openFirewall = true;
      };
      systemd.services.cups.aliases = [ "printing.service" ];
      hardware.printers = {
        ensurePrinters = [{
          name = "hp-m283fdw";
          description = "HP Color LaserJet MFP M283fdw";
          location = "Home Office";
          deviceUri = "ipp://hp-mfp.home.lan/ipp/print";
          model = "everywhere";
        }];
        ensureDefaultPrinter = "hp-m283fdw";
      };
    };
  };

  den.aspects.virtualization-aspect = {
    nixos = { ... }: {
      services.qemuGuest.enable = true;
      boot.kernelParams = [ "console=tty0" "console=ttyS0,115200n8" ];
      systemd.services."serial-getty@ttyS0" = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.Restart = "always";
      };
      systemd.services.qemu-guest-agent.serviceConfig.TimeoutStopSec = "20s";
    };
  };
}
