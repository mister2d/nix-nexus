{ pkgs, ... }:

{
  # System-level Ceph integration
  # This module provides system-wide services for managing CephFS mounts,
  # specifically ensuring they are cleanly unmounted before the system
  # enters a state (sleep, shutdown) that would break network connectivity.

  systemd.services.ceph-mount-teardown = {
    description = "Unmount CephFS volumes before sleep, suspend, or shutdown";

    # Timing is critical: Must happen BEFORE sleep and BEFORE the network drops.
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
      User = "ddukes"; # Execute as the primary user to avoid permission shadowing

      # Inject necessary environment variables for the user-space script.
      Environment = [
        "HOME=/home/ddukes"
        "XDG_RUNTIME_DIR=/run/user/1000"
      ];

      # Prevent system hangs if the network is already dead.
      TimeoutStartSec = "15s";

      # Use the user-space controller to list and teardown all known volumes.
      ExecStart = "${pkgs.bash}/bin/bash -c 'SCRIPT_PATH=\"/etc/profiles/per-user/ddukes/bin/ceph_mount_ctl\"; if [[ -x \"$SCRIPT_PATH\" ]]; then for alias in $(\"$SCRIPT_PATH\" list); do \"$SCRIPT_PATH\" unmount \"$alias\"; done; fi'";
    };
  };
}
