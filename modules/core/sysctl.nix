_:

{
  # Kernel Tuning
  boot.kernel.sysctl = {
    # Lower swappiness to prefer keeping application data in physical RAM.
    # Recommended value for workstations with 16GB+ of memory.
    "vm.swappiness" = 10;

    # Decrease VFS cache pressure to encourage the kernel to keep
    # directory and inode metadata in memory longer (useful for ZFS/Desktop).
    "vm.vfs_cache_pressure" = 50;
  };
}
