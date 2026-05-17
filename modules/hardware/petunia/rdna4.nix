{ ... }:

{
  # rdna4-full (base + rocm + power + build-env) is imported at the flake level.
  # This file holds petunia-specific option values for those shared modules.

  # llama.cpp / HIP / Vulkan build toolchain enabled system-wide.
  rdna4.buildEnv = {
    enable = true;
    enableRocm = true;
    enableVulkan = true;
  };
}
