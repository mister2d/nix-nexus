# petunia — Inference Stack SBOM

Captured: 2026-07-07  
NixOS: `26.11.20260705.d407951 (Zokor)` — nixpkgs-unstable  
System: `/nix/store/n8zpz2pszj1my3dvszprmgshzqi14v9z-nixos-system-petunia-26.11.20260705.d407951`

---

## Hardware

| Component | Detail |
|---|---|
| CPU | AMD Ryzen 5 5600X — 6 cores / 12 threads, 4.65 GHz boost |
| RAM | 64 GiB DDR4 |
| GPU 0 | AMD Radeon AI PRO R9700 (Navi 48 / GFX1201) — 32 GiB VRAM, PCI 0e:00.0 |
| GPU 1 | AMD Radeon AI PRO R9700 (Navi 48 / GFX1201) — 32 GiB VRAM, PCI 11:00.0 |
| Combined VRAM | 64 GiB (dual independent, NVLink-less PCIe topology) |
| Storage | 932 GiB NVMe (LUKS2+ZFS, system), 1.9 TiB NVMe (data), 477 GiB NVMe (secondary) |
| Swap | 66 GiB encrypted NVMe partition |
| Network | WiFi (wlp6s0, 10.0.1.156/24), Tailscale (100.80.115.82/32) |

---

## Kernel

| Item | Value |
|---|---|
| Kernel | `7.1.1-cachyos` (CachyOS BORE+EEVDF scheduler variant) |
| Build | NixOS SMP PREEMPT |
| Arch | x86_64 |

---

## GPU Compute Stack

### ROCm (HIP runtime and libraries)

All 7.2.3 packages sourced from `nixpkgs-unstable d407951` (2026-07-05).  
Target ISA: `amdgcn-amd-amdhsa--gfx1201` (RDNA4) and `gfx12-generic`.

| Package | Version | Notes |
|---|---|---|
| `rocm-core` | 7.2.3 | Version anchor |
| `rocm-runtime` (HSA) | 7.2.3 | HSA/ROCR host runtime |
| `rocm-smi` | 7.2.3 | System management interface (lib 7.8.0, CLI 4.0.0) |
| `rocm-comgr` | 22.0.0-rocm | Code object manager (LLVM 22 based) |
| `rocm-device-libs` | 22.0.0-rocm | Device-side bitcode libraries |
| `rocm-toolchain` | — | Compiler toolchain meta |
| `rocm-combined-gfx1201` | — | gfx1201-targeted combined closure |
| `rocprofiler-register` | 7.2.3 | Profiler tool registration |

### HIP

| Library | Version | Soname |
|---|---|---|
| `libamdhip64` (HIP runtime) | 7.2.53211 | `libamdhip64.so.7` |
| `libhiprtc` | 7.2.53211 | `libhiprtc.so.7` |
| `libhiprtc-builtins` | 7.2.53211 | `libhiprtc-builtins.so.7` |
| `hipClang` | 22.0.0-rocm | AOT/JIT compiler |
| `hipcc` | — | HIP compiler wrapper |

### ROCm Math / Compute Libraries

| Library | Version | Soname |
|---|---|---|
| `rocblas` | 7.2.3 | `librocblas.so.5.2.70203` |
| `hipblas` | 7.2.3 | `libhipblas.so.3.2.70203` |
| `hipblas-common` | 7.2.3 | Header-only compatibility shim |
| `hipblaslt` | 7.2.3 | `libhipblaslt.so` (LT = batched/strided BLAS extensions) |
| `rocsolver` | 7.2.3 | `librocblas` backend; LAPACK-equivalent |
| `rocwmma` | 7.2.3 | Wave Matrix Multiply-Accumulate (Tensor-core equivalent) |

### LLVM / Compiler Infrastructure (ROCm)

| Package | Version |
|---|---|
| `llvm-rocm` | 22.0.0 |
| `clang-rocm` | 22.0.0 |
| `lld-rocm` | 22.0.0 |
| `openmp-rocm` | 22.0.0 |
| `compiler-rt-libc-rocm` | 22.0.0 |
| `llvm-binutils-rocm` | 22.0.0 |

### OpenCL

| Package | Version | Notes |
|---|---|---|
| `libamdocl64` | 2.1.70203 | AMD OpenCL ICD |
| OpenCL platform | AMD Accelerated Parallel Processing | 2 devices (GPU 0 + GPU 1) |
| OpenCL C version | 2.0 | Per device |
| Compute units | 32 per GPU (64 total) | |
| Global memory | 32 GiB per GPU | |

### ONNX Runtime

| Package | Version | Notes |
|---|---|---|
| `onnxruntime` | 1.26.0 | ROCm-enabled build |

---

## Vulkan Stack

| Item | Value |
|---|---|
| Vulkan Instance | 1.4.341 |
| GPU 0 | AMD Radeon AI PRO R9700 (RADV GFX1201) |
| GPU 1 | AMD Radeon AI PRO R9700 (RADV GFX1201) |
| Software ICD | llvmpipe (LLVM 21.1.8, 256-bit) |
| Driver | `radv` (Mesa RADV) |
| Mesa version | 26.1.4 |
| Vulkan API supported | 1.4.354 |
| RADV driver version | 26.1.4 (`driverVersion = 109056004`) |
| Vendor ID | `0x1002` (AMD) |
| Device ID | `0x7551` (Navi 48 / R9700) |
| `libvulkan` | 1.4.341.0 |
| Vulkan validation layers | 1.4.341 (Khronos) |
| Notable instance extensions | `VK_KHR_display`, `VK_EXT_acquire_drm_display`, `VK_EXT_headless_surface`, `VK_KHR_external_*` |
| Notable device features | `VK_AMD_anti_lag`, `VK_EXT_debug_marker`, `VK_EXT_tooling_info` |

### Mesa / Graphics Userspace

| Package | Version |
|---|---|
| `mesa` | 26.1.4 |
| `mesa-libgbm` | 26.1.4 |
| `libdrm` | 2.4.133 (primary) |
| LLVM (Mesa/llvmpipe) | 21.1.8 |

---

## GPU Tools

| Tool | Source package | Notes |
|---|---|---|
| `rocminfo` | rocminfo-7.2.3 | HSA agent enumeration |
| `rocm-smi` | rocm-smi-7.2.3 | GPU monitoring and control |
| `amdgpu_top` | amdgpu_top-0.11.5 | Live GPU utilization (TUI) |
| `amdgpu-arch` | rocm-toolchain | GPU ISA detection |
| `hipconfig` | hipClang | HIP environment info |
| `hipcc` | hipClang | HIP compiler driver |
| `amdclang` / `amdclang++` | llvm-22.0.0-rocm | AOT device compiler |
| `amdflang` | llvm-22.0.0-rocm | Fortran for ROCm |
| `amdlld` | lld-22.0.0-rocm | ROCm linker |
| `vulkan-tools` | 1.4.341.0 | `vulkaninfo`, `vkcube` |
| `rocm_agent_enumerator` | rocm-toolchain | Agent/GPU listing utility |

---

## System Configuration Notes

### RDNA4 dual-GPU wiring

Managed by `tenarches/nix-rdna4` flake (commit `3f78e85`):
- `rdna4.dualGpu.enable = true`
- `rdna4.buildEnv.enableRocm = true`
- `rdna4.buildEnv.enableVulkan = true`
- `rocm-combined-gfx1201` closure pulled for both cards

### Runtime environment

`ROCR_VISIBLE_DEVICES`, `HIP_VISIBLE_DEVICES`, and related env vars are available to scope workloads per GPU.  
Both GPUs export as HSA agents 2 and 3 (agent 1 is the CPU).

### Inference service posture

No persistent inference daemon (ollama, vllm, triton server) is configured at the system level. Workloads run as user processes or Docker containers (`docker.service` is active). `onnxruntime-1.26.0` is the only system-level ML runtime installed.

---

## Python ML Packages (system closure, not venv)

| Package | Version |
|---|---|
| `python3.11-numpy` | 2.3.5 |
| `python3.11-scipy` | 1.16.3 |
| `python3.13-pillow` | 12.2.0 |

> Full ML stacks (PyTorch, Transformers, etc.) are expected to live in user virtualenvs or Docker images, not the system closure.

---

## Version History

| Date | Event |
|---|---|
| 2026-07-07 | Initial SBOM captured; nixpkgs-unstable d407951, ROCm 7.2.3, Mesa 26.1.4 |
| 2026-07-07 | nixpkgs-unstable bumped from 567a49d (2026-06-16) → d407951 (2026-07-05); ROCm 7.2.1 → 7.2.3; Mesa 26.1.2 → 26.1.4 |
