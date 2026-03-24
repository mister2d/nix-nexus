{ lib, config, ... }:

{
  # System Stability & Memory Pressure Handling
  # vm.* sysctls are global host-kernel tunables; they are not namespace-scoped
  # and cannot be applied from inside any LXC container (privileged or not).
  # They are guarded here so the workstation profile benefits from them while
  # container hosts (boot.isContainer = true) skip them without error.
  boot.kernel.sysctl = lib.mkIf (!config.boot.isContainer) {
    # Prefer keeping application data in physical RAM; swapping to ZFS zvol
    # can lead to kernel deadlocks under extreme memory pressure.
    "vm.swappiness" = 10;

    # Encourage the kernel to keep directory and inode metadata in memory longer.
    # This improves responsiveness for ZFS-heavy file operations and desktop usage.
    "vm.vfs_cache_pressure" = 50;

    # Increase the minimum free memory threshold to 256MB (from 67MB default).
    # This provides the kernel enough headroom to handle urgent memory allocations
    # before triggering the OOM killer.
    "vm.min_free_kbytes" = 262144;
  };

  # Early OOM Killer
  # Proactively terminates the most memory-intensive process before the system
  # enters a hard-lock state. Works in both bare-metal and container environments.
  services.earlyoom = {
    enable = true;
    # Kill processes when free RAM falls below 5% or swap falls below 10%.
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
  };
}
