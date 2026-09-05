# Merged into: flake.modules.nixos.hardware-petunia
# Configures: dual RDNA4 R9700 graphics, ROCm compute, and driver environment.
# Imported by: hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.hardware-petunia =
    { pkgs, ... }:
    {
      # Dual R9700 (RDNA4, gfx1201) graphics + ROCm compute wiring.
      #
      # RADV (Mesa) is the sole Vulkan driver. amdgpu exposes two independent
      # interfaces to each gfx1201 device:
      #   DRM/KMS → /dev/dri/renderD12x (Mesa/RADV — Vulkan path)
      #   KFD     → /dev/kfd            (ROCm CLR — compute path)
      # Both interfaces run at the same time with no driver-level conflict.
      #
      # ROCm 7.x recognizes gfx1201 natively. HSA_OVERRIDE_GFX_VERSION forces
      # the wrong ISA at the HSA runtime level and causes wrong code
      # generation. This module leaves it unset.
      #
      # The system closure excludes the HIP/Vulkan build toolchain. Inference
      # projects consume github:tenarches/nix-rdna4 devShells (llama-rocm /
      # llama-vulkan) directly.

      services = {
        xserver.videoDrivers = [ "amdgpu" ];

        # GPU power/thermal daemon: power limits, fan curves, OC/UV via sysfs.
        # Runtime config at /etc/lact/config.yaml is intentionally imperative —
        # tuning is iterative and hardware-specific.
        lact.enable = true;

        # /dev/kfd is the HSA compute interface; users need the `render` group.
        udev.extraRules = ''
          SUBSYSTEM=="drm",  KERNEL=="renderD*", GROUP="render", MODE="0660"
          KERNEL=="kfd",                         GROUP="render", MODE="0660"
        '';
      };

      # amdgpu.gpu_recovery=1     — soft GPU reset on timeout instead of hard
      #                             hang; critical for LLM inference loads.
      # amdgpu.lockup_timeout=10000 — ROCm kernels can legitimately run for
      #                             seconds; the default 5s causes false resets.
      # iommu=pt                  — IOMMU passthrough; lower DMA translation
      #                             overhead for GPU compute.
      # pcie_bus_config=performance — maximize PCIe read request size for
      #                             inter-GPU DMA throughput (dual-GPU).
      boot.kernelParams = [
        "amdgpu.gpu_recovery=1"
        "amdgpu.lockup_timeout=10000"
        "iommu=pt"
        "pcie_bus_config=performance"
      ];

      hardware = {
        # Early KMS: stable splash and render nodes before user-space starts.
        amdgpu.initrd.enable = true;

        # ppfeaturemask unlock for LACT's overclock/power-cap interface.
        amdgpu.overdrive.enable = true;

        graphics = {
          enable = true;
          enable32Bit = true; # Wine, Steam, 32-bit Vulkan clients

          extraPackages = [
            # OpenCL dispatch layer via ROCm CLR; the full compute stack is
            # provided through the /opt/rocm symlink below.
            pkgs.rocmPackages.clr.icd

            # VA-API for RDNA4's multimedia engine (AV1, H.265 decode/encode).
            pkgs.libva
          ];

          extraPackages32 = [ pkgs.pkgsi686Linux.libva ];
        };
      };

      # This symlink provides /opt/rocm, the hard-coded library path AMD's
      # toolchain and most ML frameworks expect. Add paths as workloads
      # require (e.g. rocSPARSE, MIOpen).
      systemd.tmpfiles.rules =
        let
          rocmEnv = pkgs.symlinkJoin {
            name = "rocm-combined-gfx1201";
            paths = [
              pkgs.rocmPackages.clr # HSA/HIP runtimes, OpenCL ICD, device libs
              pkgs.rocmPackages.rocblas # BLAS kernels — LLM matrix-op critical path
              pkgs.rocmPackages.hipblas # HIP BLAS API over rocBLAS
              pkgs.rocmPackages.rocminfo
              pkgs.rocmPackages.rocm-smi
            ];
          };
        in
        [ "L+ /opt/rocm - - - - ${rocmEnv}" ];

      environment.sessionVariables = {
        # Both R9700s visible to the HSA runtime; HIP indices 0 and 1.
        ROCR_VISIBLE_DEVICES = "0,1";
        # Explicit ISA target for tools that JIT-compile HIP kernels.
        HCC_AMDGPU_TARGET = "gfx1201,gfx1201";
        LIBVA_DRIVER_NAME = "radeonsi";
        VDPAU_DRIVER = "radeonsi";
      };

      environment.systemPackages = [
        pkgs.rocmPackages.rocminfo # enumerate HSA agents; verify 2x gfx1201
        pkgs.rocmPackages.rocm-smi # GPU power, temperature, clock states
        pkgs.nvtopPackages.amd # real-time GPU utilization
        pkgs.amdgpu_top # detailed AMDGPU metrics: clocks, VRAM, power
        pkgs.vulkan-tools # vulkaninfo, vkcube
        pkgs.clinfo # verify the OpenCL ICD is visible
        pkgs.lm_sensors # board temperatures and fan speeds
      ];
    };
}
