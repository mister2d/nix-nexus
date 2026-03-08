_:

{
  # System Stability & Memory Pressure Handling
  # These tunables prevent system-wide lockups during heavy Nix builds or
  # resource-intensive research workloads, especially when using ZFS swap.
  boot.kernel.sysctl = {
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
  # Proactively terminates the most memory-intensive process (typically a heavy
  # nix-build or browser process) before the system enters a hard-lock state
  # caused by ZFS ARC/Swap competition.
  services.earlyoom = {
    enable = true;
    # Kill processes when free RAM falls below 5% or swap falls below 10%.
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
  };
}
