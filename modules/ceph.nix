{
  lib,
  ...
}:
{

  den.aspects.ceph-aspect = lib.mkForce {
    nixos =
      { pkgs, ... }:
      {
        systemd.services.ceph-mount-teardown = {
          description = "Unmount CephFS volumes before sleep, suspend, or shutdown";
          before = [
            "sleep.target"
            "suspend.target"
            "shutdown.target"
            "network-pre.target"
            "NetworkManager.service"
          ];
          wantedBy = [
            "sleep.target"
            "suspend.target"
            "shutdown.target"
          ];
          serviceConfig = {
            Type = "oneshot";
            User = "ddukes";
            Environment = [
              "HOME=/home/ddukes"
              "XDG_RUNTIME_DIR=/run/user/1000"
            ];
            TimeoutStartSec = "15s";
            ExecStart = "${pkgs.bash}/bin/bash -c 'SCRIPT_PATH=\"/etc/profiles/per-user/ddukes/bin/ceph_mount_ctl\"; if [[ -x \"$SCRIPT_PATH\" ]]; then for alias in $(\"$SCRIPT_PATH\" list); do \"$SCRIPT_PATH\" unmount \"$alias\"; done; fi'";
          };
        };
      };
  };
}
