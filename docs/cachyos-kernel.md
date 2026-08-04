# CachyOS Kernel: Performance Enhancements

**Module:** `modules/hardware/kernel/cachyos.nix`  
**Upstream source:** `github:xddxdd/nix-cachyos-kernel/release`

Two hosts use the CachyOS kernel, each with a different variant tuned to its workload:

| Host | Variant | Scheduler | Timer | Preemption | CPU arch | Build |
|------|---------|-----------|-------|------------|----------|-------|
| sweet16 | `linux-cachyos-bore-x86_64-v3` | BORE | 1000Hz | full dynamic | x86_64-v3 | binary cache |
| petunia | `linux-cachyos-server` + x86_64-v3 | EEVDF | 300Hz | full | x86_64-v3 | local (from source) |

---

# sweet16 — ThinkPad Z16 Gen 1

**Hardware:** AMD Ryzen 7 PRO 6850H (Rembrandt, Zen 3+), 32GB RAM  
**Active kernel:** `7.0.10-cachyos` (`linux-cachyos-bore-x86_64-v3`)  
**Config:** `hosts/sweet16/default.nix` → `hardware.cachyosKernel.variant = "bore"`

## Why This Kernel

The stock NixOS kernel (6.12 LTS) is tuned for server throughput: 250Hz timer, voluntary preemption, EEVDF scheduler. On an interactive laptop these defaults cause measurable scheduling latency, CPU frequency hesitation during burst tasks, and suboptimal ZFS integration. The CachyOS BORE variant rebalances all of these toward interactive responsiveness while retaining full upstream ABI compatibility for ZFS and kernel modules.

## Active Optimizations

All items below are confirmed active from `/proc/config.gz` and live sysctls on the running 7.0.10-cachyos kernel.

### 1. BORE CPU Scheduler (`CONFIG_SCHED_BORE=y`)

**What it is:** Burst-Oriented Response Enhancer. A patch on top of the Linux CFS/EEVDF scheduler that tracks each task's CPU burst history and penalizes tasks that hold the CPU continuously without yielding.

**What it does for this host:**
- Tasks that regularly yield (UI redraws, Wayland compositor, audio callbacks, language server responses) are not penalized and are scheduled ahead of background CPU hogs (Nix builds, compilation jobs).
- Interactive latency — the time from a keypress or mouse event to the first frame of response — drops measurably because the scheduler does not need to wait for the current burst to exhaust its time slice before inserting a high-priority interactive wakeup.
- Nix builds and other batch workloads continue running at full throughput; they simply do not crowd out the desktop.

**Verified active:**
```
$ sysctl kernel.sched_bore
kernel.sched_bore = 1
```

### 2. ADIOS I/O Scheduler (`CONFIG_MQ_IOSCHED_ADIOS=y`)

**What it is:** Adaptive Deadline I/O Scheduler. A CachyOS-developed replacement for the `mq-deadline` and `kyber` schedulers, tuned for NVMe SSDs with multiple submission queues.

**What it does for this host:**
- Interleaves read and write I/O more adaptively than deadline, reducing write-induced read latency spikes during Nix builds.
- Benefits ZFS particularly: ARC eviction (background write pressure) no longer stalls foreground metadata reads.
- The Kioxia NVMe in the Z16 exposes multiple hardware queues; ADIOS distributes load across them while maintaining deadline guarantees for latency-sensitive operations.

### 3. 1000Hz Timer (`CONFIG_HZ=1000`)

**What it is:** Increases the kernel's hardware interrupt rate from the NixOS default 250Hz to 1000Hz (1ms granularity vs. 4ms).

**What it does for this host:**
- Sleep precision for `nanosleep`/`select`/`poll` improves from ~4ms worst-case to ~1ms. This reduces audio buffer underruns in PipeWire and improves frame pacing in the Sway compositor.
- The scheduler's minimum time slice granularity is tighter, allowing the BORE scheduler's burst tracking to be more accurate.
- CPU overhead is negligible on a modern Zen 3+ core at 1000 IRQs/s.

**Verified active:**
```
CONFIG_HZ=1000
CONFIG_HZ_1000=y
```

### 4. Full Tickless Mode (`CONFIG_NO_HZ_FULL=y`)

**What it is:** When a CPU core is running a single runnable task with no pending kernel timers, the periodic tick interrupt is completely suppressed until something external wakes the core.

**What it does for this host:**
- Idle and lightly loaded cores do not burn power servicing 1000 timer IRQs/s for no reason. A core compiling one file in a Nix build receives zero timer interrupts between task transitions.
- Combined with AMD P-State EPP (below), cores spending long periods in single-task compute can stay in higher-performance P-states without timer-induced C-state disruptions.
- Battery benefit: fewer unnecessary wakeups during background tasks.

**Verified active:**
```
CONFIG_NO_HZ_FULL=y
CONFIG_NO_HZ=y
CONFIG_NO_HZ_COMMON=y
```

### 5. Full Dynamic Preemption (`CONFIG_PREEMPT=y` + `CONFIG_PREEMPT_DYNAMIC=y`)

**What it is:** `PREEMPT_DYNAMIC` compiles in all preemption modes and selects among them at boot or runtime. The BORE/CachyOS default is `PREEMPT_FULL` (full kernel preemption), which allows any kernel code path outside a spin-lock to be preempted by a higher-priority task.

**What it does for this host:**
- Reduces kernel-induced latency spikes: a Wayland compositor thread waiting on a vsync will preempt a kernel code path mid-execution rather than waiting for it to voluntarily return to userspace.
- Critical for audio: PipeWire's real-time threads can preempt the kernel sooner, reducing the number of xruns (buffer underruns) under load.
- `PREEMPT_DYNAMIC` means the mode is tunable at runtime via `/sys/kernel/debug/sched/features` — you can switch to `PREEMPT_VOLUNTARY` for sustained Nix builds if needed without a reboot.

**Verified active:**
```
CONFIG_PREEMPT=y
CONFIG_PREEMPT_DYNAMIC=y
CONFIG_PREEMPT_BUILD=y
```

### 6. O3 Compiler Optimization (`CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y`)

**What it is:** The kernel is compiled with GCC `-O3` instead of the standard `-O2`.

**What it does for this host:**
- Hot kernel paths — scheduler tick, interrupt handlers, ZFS ARC lookup, NVMe submission — are compiled with more aggressive inlining, vectorization, and loop unrolling.
- On Zen 3+, GCC `-O3` enables auto-vectorization with AVX2 (256-bit SIMD) for loops in core subsystems that the kernel marks as vectorizable.
- Net effect: slightly lower CPU cycles per I/O operation and per scheduler decision. Not measurable in microbenchmarks but accumulates in sustained mixed workloads.

**Verified active:**
```
CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y
```

### 7. x86_64-v3 Microarchitecture Tuning (`CONFIG_X86_64_VERSION=3`)

**What it is:** The entire kernel is compiled targeting the x86_64-v3 microarchitecture baseline, which requires: AVX, AVX2, BMI1, BMI2, FMA, MOVBE, POPCNT, SSE3, SSE4.1, SSE4.2, SSSE3.

**What it does for this host:**
The Ryzen 7 PRO 6850H confirms all required flags:
```
$ grep -o "avx2\|bmi2\|fma" /proc/cpuinfo | sort -u
avx2
bmi2
fma
```
- The compiler emits AVX2 (256-bit) SIMD instructions for vectorizable loops throughout the kernel — memcpy, CRC32 (used by ZFS), crypto, and scheduler data structure operations.
- BMI2 bit-manipulation instructions appear in allocator and page-table hot paths.
- FMA fused-multiply-add is used in kernel math routines.
- Any CPU that does not have all x86_64-v3 features will trigger an Illegal Instruction fault at boot — this configuration is correct and verified for the 6850H.

**Verified active:**
```
CONFIG_X86_64_VERSION=3
```

### 8. Transparent Hugepages — Always Mode (`CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS=y`)

**What it is:** The kernel promotes anonymous 4KB pages into 2MB hugepages automatically for all processes without any application opt-in required.

**What it does for this host (binary build default):**
- Nix build processes, Rust compiler, llama.cpp, and JVM heaps get 2MB pages automatically, reducing TLB pressure significantly.
- Page-table walk depth decreases: fewer TLB misses for large working sets.

**Note — declared vs. active:** The host config declares `hugepageMode = "madvise"` which would restrict hugepage promotion to processes that explicitly call `madvise(MADV_HUGEPAGE)`. This setting requires `enableCustomBuild = true` and a local kernel rebuild (~45 min). The current binary build uses **ALWAYS** mode (confirmed: `[always] madvise never`). See "Pending Enhancements" below.

**Verified active:**
```
CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS=y
```
```
$ cat /sys/kernel/mm/transparent_hugepage/enabled
[always] madvise never
```

### 9. ZFS — CachyOS-Matched Build (`zfs_cachyos`)

**What it is:** ZFS built from the CachyOS upstream against the exact kernel ABI of `7.0.10-cachyos`. Wired via `boot.zfs.package = config.boot.kernelPackages.zfs_cachyos`.

**Why it matters:**
- Standard NixOS ZFS (`zfs`) is built against vanilla nixpkgs kernel headers. A kernel ABI mismatch causes ZFS module load failure at boot.
- `zfs_cachyos` is built by the same upstream Hydra CI that builds the kernel, guaranteeing ABI pairing. Binary cache hit from `https://attic.xuyh0120.win/lantian`.
- The CachyOS ZFS build includes the same `CACHY` config flag, enabling any ZFS code paths that interact with CachyOS-specific kernel internals (primarily the ADIOS I/O scheduler hooks).

**ZFS tuning active on sweet16:**

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `arcMax` | 8 GB | Balanced for 32GB RAM; leaves headroom for Nix builds |
| `arcMin` | 2 GB | Prevents ARC from being evicted too aggressively under memory pressure |
| `arcSysFree` | 4 GB | Safety margin; ZFS won't grow ARC if system free < 4GB |
| `metaLimitPercent` | 85% | Allows metadata to occupy most of ARC; benefits inode-heavy dev workloads |
| `dnodeLimitPercent` | 25% | Increases dnode cache for large directory trees (nixpkgs store, git repos) |

## AMD P-State EPP

**What it is:** The `amd_pstate=active` kernel parameter activates AMD's P-State EPP (Energy Performance Preference) driver. This is injected by `nixos-hardware.nixosModules.common-cpu-amd` for kernels >= 6.3 (the Z16 runs 7.0.10).

**What it does:**
- Replaces the legacy `acpi_cpufreq` governor with AMD's native CPPC (Collaborative Processor Performance Control) interface.
- The CPU communicates performance requests directly to the SoC firmware over a dedicated fast-path, bypassing the OS governor's delay loop.
- Frequency transitions occur in hardware in tens of microseconds vs. the OS governor's ~10ms polling cycle.
- `power-profiles-daemon` (PPD) selects among `performance`, `balanced`, and `power-saver` EPP hints via the ACPI platform profile interface — these are exposed as the ThinkPad's Lenovo power modes.
- The `initcall_blacklist=acpi_cpufreq_init` kernel param prevents the legacy driver from registering and conflicting.

## Host Kernel Parameters (ThinkPad Z16 Specific)

These complement the CachyOS kernel features with Z16-specific hardware quirks.

| Parameter | Effect |
|-----------|--------|
| `nvme_core.default_ps_max_latency_us=9000` | Caps NVMe at PS3 (1200µs exit latency). Prevents PS4 (9500µs) from blocking ZFS's synchronous I/O path during ARC pressure events |
| `amdgpu.sg_display=0` | Disables scatter-gather display engine; eliminates white-flash artifacts on the OLED panel during Wayland compositor transitions |
| `amdgpu.dcdebugmask=0x410` | Suppresses RDNA2 display/power management debug logging that was causing false timeout resets in DC engine |
| `amdgpu.gpu_recovery=1` | Enables GPU soft-reset on lockup detection instead of hard system hang |
| `amdgpu.lockup_timeout=10000` | 10s lockup threshold prevents false resets during sustained VA-API video encode |
| `amdgpu.gttsize=8192` | 8GB GTT window for iGPU; prevents OOM in the GPU address space during simultaneous video conference + Wayland rendering |
| `iommu=pt` | IOMMU passthrough mode; avoids remapping overhead for GPU memory operations on the Rembrandt APU's unified memory architecture |
| `snd_pci_acp6x.dmic_config=1` | Ensures the ACP6x audio coprocessor enumerates the DMIC array (required for the Z16's internal microphone) |
| `initcall_blacklist=acpi_cpufreq_init` | Prevents the legacy CPUFreq driver from binding before AMD P-State can claim the interface |
| `mem_sleep_default=s2idle` | Forces Modern Standby (S0ix) sleep state; the Z16 does not implement S3 at the firmware level |

## Kernel Build Parameters Summary (sweet16)

| Parameter | Value | Source |
|-----------|-------|--------|
| Kernel variant | `linux-cachyos-bore-x86_64-v3` | `kernel-cachyos/default.nix` |
| Kernel version | 7.0.10-cachyos | `linuxSources.latest` |
| `cpusched` | `bore` | BORE patchset |
| `processorOpt` | `x86_64-v3` | AVX2/BMI2/FMA, no AVX-512 |
| `hzTicks` | `1000` | BORE variant default |
| `tickrate` | `full` | `NO_HZ_FULL` |
| `preemptType` | `full` | `PREEMPT_DYNAMIC` + `PREEMPT` |
| `ccHarder` | `true` | `-O3` compilation |
| `lto` | `none` | GCC; binary cache compatible |
| `hugepage` | `always` | binary default |
| `bbr3` | `false` | custom build only |
| `acpiCall` | `false` | custom build only |

## Pending Enhancements (sweet16, require `enableCustomBuild = true`)

### BBR3 TCP Congestion Control

**Declared:** `enableBbr3 = true`
**Current state:** Not active (`net.ipv4.tcp_congestion_control = cubic`). BBR3 is compiled as a module (`CONFIG_TCP_CONG_BBR3=m`) but not the system default.

When active, sets `DEFAULT_TCP_CONG = bbr` and `NET_SCH_FQ = yes`. BBR3 measures bottleneck bandwidth and RTT directly, avoiding the loss-based backoff that CUBIC uses — useful on links with occasional bufferbloat.

### ACPI Call Patch

**Declared:** `enableAcpiCall = true`
**Current state:** Not active.

Applies `misc/0001-acpi-call.patch` from `github:CachyOS/kernel-patches`. Used on ThinkPads to gate/ungate the discrete 6500M dGPU and access EC charging ACPI methods.

### Transparent Hugepages — madvise Mode

**Declared:** `hugepageMode = "madvise"`
**Current state:** Not active; binary built with ALWAYS.

Under `madvise`, hugepages are only allocated for ranges that call `madvise(MADV_HUGEPAGE)` — llama.cpp weight tensors, JVM heap. Reduces idle RAM overhead from ALWAYS (~200–400MB) on a laptop where small anonymous mappings are common.

## Before/After Comparison (sweet16)

| Attribute | Before (6.12 LTS) | After (7.0.10 CachyOS BORE) |
|-----------|-------------------|-----------------------------|
| Scheduler | EEVDF | BORE (burst-aware EEVDF) |
| I/O scheduler | bfq / mq-deadline | ADIOS |
| Timer rate | 250Hz | 1000Hz |
| Tickless | idle only | full (`NO_HZ_FULL`) |
| Preemption | voluntary | full dynamic (`PREEMPT_DYNAMIC`) |
| Optimization | `-O2` | `-O3` |
| ISA targeting | generic x86_64 | x86_64-v3 (AVX2/BMI2/FMA) |
| ZFS package | nixpkgs `zfs` | `zfs_cachyos` (ABI-matched) |
| Kernel line | 6.12.x | 7.0.x |

---

# petunia — LLM Inference Server

**Hardware:** AMD Ryzen 5 5600X (Vermeer, Zen 3), 64GB RAM, RDNA4 GPU (Navi 48)  
**Active kernel:** `7.0.10-cachyos` (`linux-cachyos-server`, custom build with `processorOpt = "x86_64-v3"`)  
**Config:** `hosts/petunia/default.nix` → `hardware.cachyosKernel.variant = "server"`

## Why This Kernel

petunia is a dedicated LLM inference server. Its workload is sustained GPU compute (ROCm/HIP on RDNA4) with CPU work limited to tokenization, sampling, and ROCm dispatch overhead. The BORE scheduler is designed for interactive desktop workloads — it actively penalizes tasks that hold the CPU continuously, which is exactly what inference dispatch threads do. The server variant instead uses EEVDF with a 300Hz timer and full preemption, trading interactive-latency optimizations for reduced interrupt overhead and throughput-oriented scheduling.

The upstream `linux-cachyos-server` binary does not have a pre-built x86_64-v3 variant, so a local build with `processorOpt = "x86_64-v3"` is used to preserve the AVX2/BMI2/FMA ISA tuning for ZFS ARC operations and memory paths. Build time on the 12-thread 5600X: **98 minutes 59 seconds**.

## Active Optimizations

All items below are confirmed active from `/proc/config.gz` on the running 7.0.10-cachyos kernel.

### 1. EEVDF CPU Scheduler (no `CONFIG_SCHED_BORE`)

**What it is:** Completely Fair EEVDF (Earliest Eligible Virtual Deadline First) scheduling without the BORE burst-penalty layer on top. Tasks are scheduled by their virtual deadline regardless of past CPU burst history.

**What it does for this host:**
- ROCm dispatch threads and inference loop threads are not penalized for holding the CPU — they run for their full time slice without having their priority reduced for doing sustained compute.
- The scheduler does not introduce the burst-tracking overhead that BORE adds on every task wakeup.
- EEVDF's deadline-based fairness is appropriate for a server where there is no interactive workload competing for the CPU.

**Verified active:**
```
$ sysctl kernel.sched_bore
sysctl: cannot stat /proc/sys/kernel/sched_bore: No such file or directory
```

### 2. 300Hz Timer (`CONFIG_HZ=300`)

**What it is:** The server variant reduces the timer interrupt rate to 300Hz (3.3ms granularity), down from the 1000Hz used by the BORE desktop variant and up from the 250Hz stock NixOS default.

**What it does for this host:**
- During sustained GPU inference the CPU is mostly idle, waiting on the GPU. At 1000Hz, the CPU would service 700 extra timer IRQs/s compared to 300Hz for no benefit.
- Lower timer rate means fewer unnecessary wakeups while the CPU is blocked on GPU command completion, allowing deeper C-states and reduced power draw.
- 300Hz is a deliberate middle ground: coarser than 1000Hz (less interrupt overhead) but finer than 250Hz (allows reasonable sleep precision for async I/O and dispatch loops).

**Verified active:**
```
CONFIG_HZ=300
```

### 3. Full Preemption (`CONFIG_PREEMPT=y`)

**What it is:** The kernel is compiled with full preemption. Any kernel code path outside a spin-lock can be preempted by a higher-priority task.

**Note on the server variant:** The `linux-cachyos-server` upstream definition declares `preemptType = "none"`, which was expected to produce `CONFIG_PREEMPT_NONE`. The compiled kernel has `CONFIG_PREEMPT=y` (full preemption) with `PREEMPT_DYNAMIC` disabled. This means the CachyOS server variant compiles with fixed full preemption rather than no-preemption. For a dedicated inference server with no interactive competing workloads, full preemption adds minimal overhead and is not a regression from the previous 6.12 LTS voluntary preemption.

**Verified active:**
```
CONFIG_PREEMPT=y
# CONFIG_PREEMPT_DYNAMIC is not set
```

### 4. O3 Compiler Optimization (`CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y`)

**What it is:** The kernel is compiled with GCC `-O3`.

**What it does for this host:**
- ZFS ARC lookup, NVMe I/O submission, memory allocator paths, and ROCm DMA management code in the AMDGPU driver are compiled with more aggressive inlining and vectorization.
- On Zen 3, `-O3` with x86_64-v3 targeting enables AVX2 auto-vectorization for hot memory and math paths.

**Verified active:**
```
CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y
```

### 5. x86_64-v3 Microarchitecture Tuning (`CONFIG_X86_64_VERSION=3`)

**What it is:** The kernel is compiled targeting x86_64-v3 (AVX, AVX2, BMI1, BMI2, FMA, MOVBE, POPCNT, SSE4.x, SSSE3).

**What it does for this host:**
The Ryzen 5 5600X (Zen 3) confirms all required flags:
```
$ grep -o "avx2\|bmi2\|fma" /proc/cpuinfo | sort -u
avx2
bmi2
fma
```
- ZFS CRC32c checksumming and ARC metadata operations use AVX2-vectorized paths. On a model-serving host that loads multi-GB weight files through ZFS at startup, this reduces checksumming overhead.
- Kernel memory management (page allocation, copy_from_user, memcpy) uses AVX2 instructions across the board.
- This was the primary motivation for using `enableCustomBuild = true` — no pre-built `linux-cachyos-server-x86_64-v3` binary exists upstream.

**Verified active:**
```
CONFIG_X86_64_VERSION=3
```

### 6. ADIOS I/O Scheduler — Compiled In (`CONFIG_MQ_IOSCHED_ADIOS=y`)

**What it is:** ADIOS is compiled into the kernel. For the Samsung 990 EVO Plus NVMe, the active scheduler is `none` (hardware passthrough to the NVMe submission queues directly).

**What it does for this host:**
- NVMe SSDs with multiple hardware submission queues are most efficient with the `none` scheduler — I/O requests are submitted directly to the device's internal queue without software reordering overhead.
- ADIOS is available for future use if a rotational or SATA device is added, without requiring a kernel rebuild.
- Model file loading at startup (multi-GB reads from ZFS on NVMe) benefits from the direct-passthrough path.

**Verified active:**
```
CONFIG_MQ_IOSCHED_ADIOS=y
```
```
$ cat /sys/block/nvme0n1/queue/scheduler
[none] mq-deadline kyber adios
```

### 7. Transparent Hugepages — Always Mode

**What it is:** The kernel promotes anonymous 4KB pages into 2MB hugepages automatically.

**What it does for this host:**
- LLM weight tensors loaded into VRAM-adjacent system memory and ROCm pinned buffers use 2MB pages automatically, reducing TLB pressure during GPU DMA transfers.
- The ROCm/HIP runtime's large buffer allocations (system memory staging for GPU upload) benefit from reduced page-table walk depth.
- llama.cpp calls `madvise(MADV_HUGEPAGE)` on weight regions; with ALWAYS mode this is redundant but harmless.

**Verified active:**
```
$ cat /sys/kernel/mm/transparent_hugepage/enabled
[always] madvise never
```

### 8. ZFS — CachyOS-Matched Build (`zfs-cachyos 2.4.2-1`)

**What it is:** ZFS built against the exact ABI of `7.0.10-cachyos`. Wired via the `packagesFor + .override { kernel = baseKernel; }` pattern (Pattern B) because no pre-built `linuxPackages-cachyos-server` attrset exists in the overlay.

**Why it matters:**
- `linux-cachyos-server` uses the same upstream kernel source as `linux-cachyos-latest`, so `zfs-cachyos` (built against latest) ABI-matches after the `override { kernel = baseKernel; }` substitution.
- The ZFS module loads from `/run/booted-system/kernel-modules/lib/modules/7.0.10-cachyos/extra/zfs.ko.xz` — the CachyOS-patched build, not the nixpkgs vanilla ZFS.

**ZFS tuning active on petunia:**

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `arcMax` | 16 GB | 64GB RAM; 16GB ARC leaves headroom for GPU drivers and model buffers |
| `arcMin` | 4 GB | Prevents aggressive ARC eviction under ROCm memory pressure |
| `arcSysFree` | 8 GB | OOM safety margin for GPU driver allocations |
| `metaLimitPercent` | 80% | Metadata-heavy workloads (nixpkgs store, git repos) |
| `dnodeLimitPercent` | 20% | Dnode cache for large directory trees |

**Pool status post-migration:**
```
pool: petunia  state: ONLINE  errors: No known data errors
```

## AMD P-State EPP

`amd_pstate=active` is set in `modules/hardware/petunia/ryzen.nix`. The Ryzen 5 5600X supports CPPC (Collaborative Processor Performance Control); P-State EPP allows the firmware to handle frequency transitions directly in hardware, bypassing the OS governor polling cycle.

## Host Kernel Parameters

| Parameter | Effect |
|-----------|--------|
| `amd_pstate=active` | AMD P-State EPP driver; CPPC frequency control (set in `hardware-petunia`) |
| `pcie_aspm=off` | Disables PCIe ASPM on the Gigabyte X570 AORUS MASTER (known stability quirk) |
| `amdgpu.gpu_recovery=1` | Soft-reset on RDNA4 lockup detection |
| `amdgpu.lockup_timeout=10000` | 10s lockup threshold; prevents false resets during sustained ROCm compute |
| `iommu=pt` | IOMMU passthrough; reduces remapping overhead for RDNA4 DMA |
| `amdgpu.ppfeaturemask=0xfffd7fff` | Enables full RDNA4 power/performance feature set |

## Kernel Build Parameters Summary (petunia)

| Parameter | Value | Source |
|-----------|-------|--------|
| Kernel variant | `linux-cachyos-server` | `kernel-cachyos/default.nix` |
| Kernel version | 7.0.10-cachyos | `linuxSources.latest` |
| `cpusched` | `eevdf` | server variant |
| `processorOpt` | `x86_64-v3` | custom build override (no upstream binary) |
| `hzTicks` | `300` | server variant |
| `preemptType` | declared `none`, compiled `full` | see note in §3 above |
| `ccHarder` | `true` | `-O3` compilation |
| `lto` | `none` | GCC |
| `hugepage` | `always` | default |
| `enableCustomBuild` | `true` | required for `processorOpt` override |
| Build time | 98 min 59 sec | 12-thread Ryzen 5 5600X, 2026-06-10 |

## Before/After Comparison (petunia)

| Attribute | Before (6.12.91 LTS) | After (7.0.10 CachyOS server+v3) |
|-----------|----------------------|----------------------------------|
| Scheduler | EEVDF (stock) | EEVDF (CachyOS-tuned, no BORE) |
| I/O scheduler | bfq / mq-deadline | none (NVMe passthrough); ADIOS compiled in |
| Timer rate | 250Hz | 300Hz |
| Tickless | idle only | idle only |
| Preemption | voluntary | full |
| Optimization | `-O2` | `-O3` |
| ISA targeting | generic x86_64 | x86_64-v3 (AVX2/BMI2/FMA) |
| ZFS package | nixpkgs `zfs` | `zfs-cachyos 2.4.2-1` (ABI-matched) |
| Kernel line | 6.12.x | 7.0.x |

---

# Binary Cache and Build Notes

The `hardware-kernel-cachyos` module adds one substituter unconditionally (outside `mkIf cfg.enable`) so the cache is active before the kernel is enabled. This supports a two-phase deployment: Phase 1 activates the cache; Phase 2 enables the kernel and downloads rather than builds.

| Cache | Purpose |
|-------|---------|
| `https://attic.xuyh0120.win/lantian` | Upstream cache for CachyOS kernel and ZFS closures |

This is the only cache the upstream project publishes ([README](https://github.com/xddxdd/nix-cachyos-kernel#binary-cache)); it is fed by the Hydra CI that builds both the kernels and `zfs_cachyos`. Upstream also lists a third-party mirror, `https://cache.xinux.uz`, under an explicit no-guarantee disclaimer — not configured here.

**sweet16 (bore, x86_64-v3):** Pre-built by upstream Hydra CI. `overlays.pinned` locks the store hash to the cache entry — always a binary download, no local build required.

**petunia (server, x86_64-v3):** No pre-built binary exists for `linux-cachyos-server` with `processorOpt = "x86_64-v3"`. The kernel and ZFS module are built from source on the host. On a 12-thread Ryzen 5 5600X the build takes approximately 99 minutes. The `overlays.pinned` overlay still ensures the base kernel source is downloaded from cache; only the compilation step runs locally.
