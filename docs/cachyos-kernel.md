# CachyOS Kernel: Performance Enhancements on sweet16

**Host:** sweet16 — ThinkPad Z16 Gen 1, AMD Ryzen 7 PRO 6850H (Rembrandt, Zen 3+)  
**Active kernel:** `7.0.10-cachyos` (`linux-cachyos-bore-x86_64-v3`)  
**Module:** `modules/hardware/kernel/cachyos.nix`  
**Upstream source:** `github:xddxdd/nix-cachyos-kernel/release`  

---

## Why This Kernel

The stock NixOS kernel (6.12 LTS, previously used on this host) is tuned for server throughput: 250Hz timer, voluntary preemption, EEVDF scheduler. On an interactive laptop these defaults cause measurable scheduling latency, CPU frequency hesitation during burst tasks, and suboptimal ZFS integration. The CachyOS BORE variant rebalances all of these toward interactive responsiveness while retaining full upstream ABI compatibility for ZFS and kernel modules.

---

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
- `zfs_cachyos` is built by the same upstream Hydra CI that builds the kernel, guaranteeing ABI pairing. Binary cache hit from `cache.garnix.io`.
- The CachyOS ZFS build includes the same `CACHY` config flag, enabling any ZFS code paths that interact with CachyOS-specific kernel internals (primarily the ADIOS I/O scheduler hooks).

**ZFS tuning active on sweet16:**

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `arcMax` | 8 GB | Balanced for 32GB RAM; leaves headroom for Nix builds |
| `arcMin` | 2 GB | Prevents ARC from being evicted too aggressively under memory pressure |
| `arcSysFree` | 4 GB | Safety margin; ZFS won't grow ARC if system free < 4GB |
| `metaLimitPercent` | 85% | Allows metadata to occupy most of ARC; benefits inode-heavy dev workloads |
| `dnodeLimitPercent` | 25% | Increases dnode cache for large directory trees (nixpkgs store, git repos) |

---

## AMD P-State EPP (from nixos-hardware)

**What it is:** The `amd_pstate=active` kernel parameter activates AMD's P-State EPP (Energy Performance Preference) driver. This is injected by `nixos-hardware.nixosModules.common-cpu-amd` for kernels >= 6.3 (the Z16 runs 7.0.10).

**What it does:**
- Replaces the legacy `acpi_cpufreq` governor with AMD's native CPPC (Collaborative Processor Performance Control) interface.
- The CPU communicates performance requests directly to the SoC firmware over a dedicated fast-path, bypassing the OS governor's delay loop.
- Frequency transitions occur in hardware in tens of microseconds vs. the OS governor's ~10ms polling cycle.
- `power-profiles-daemon` (PPD) selects among `performance`, `balanced`, and `power-saver` EPP hints via the ACPI platform profile interface — these are exposed as the ThinkPad's Lenovo power modes.
- The `initcall_blacklist=acpi_cpufreq_init` kernel param prevents the legacy driver from registering and conflicting.

---

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

---

## Binary Cache Deployment

The `linux-cachyos-bore-x86_64-v3` kernel is pre-built by upstream Hydra CI. The module adds two substituters so the closure is downloaded rather than compiled:

| Cache | Purpose |
|-------|---------|
| `https://attic.xuyh0120.win/lantian` | Primary cache for CachyOS kernel closures |
| `https://cache.garnix.io` | Secondary; also hosts ZFS and module package closures |

The `overlays.pinned` overlay locks `pkgs.cachyosKernels` to the exact Hydra-built attrset, ensuring the store hash matches the cache entry. Using `overlays.default` instead would rebuild from source.

These substituter settings are applied **unconditionally** (outside `mkIf cfg.enable`) to support the two-phase deployment pattern: Phase 1 activates the cache before the kernel is enabled, so the first `enable = true` rebuild is a binary download rather than a 45-minute local build.

---

## Pending Enhancements (Require `enableCustomBuild = true`)

These are declared in `hosts/sweet16/default.nix` but are not active in the current binary build. Enabling them requires setting `enableCustomBuild = true`, which invalidates the Hydra cache hash and triggers a full local kernel build (~45 min on the 6850H).

### BBR3 TCP Congestion Control

**Declared:** `enableBbr3 = true`
**Current state:** Not active (`net.ipv4.tcp_congestion_control = cubic`). BBR3 is compiled as a module (`CONFIG_TCP_CONG_BBR3=m`) but not the system default.

When active (custom build), `cachySettings.bbr3` sets:
```
TCP_CONG_BBR = yes
DEFAULT_BBR = yes
DEFAULT_TCP_CONG = bbr
NET_SCH_FQ = yes       # Fair Queue — BBR3's required qdisc
NET_SCH_FQ_CODEL = module
```
BBR3 measures the bottleneck bandwidth and RTT directly and adjusts the send rate to keep inflight data at exactly one BDP. On a high-speed WiFi or Ethernet link with occasional bufferbloat (hotel networks, hotspots), BBR3 maintains throughput while eliminating the latency spikes that CUBIC causes by backing off only after detecting loss.

### ACPI Call Patch

**Declared:** `enableAcpiCall = true`
**Current state:** Not active (patch not applied to binary build).

Applies `misc/0001-acpi-call.patch` from `github:CachyOS/kernel-patches`. This exposes the kernel's `acpi_call` interface, allowing userspace to invoke arbitrary ACPI methods. On ThinkPads this is used to:
- Gate/ungate the discrete 6500M dGPU via ACPI power methods when switching between iGPU-only and hybrid GPU modes.
- Access ThinkPad EC charging methods for finer battery control beyond what the `charge_control_*_threshold` sysfs interface exposes.

### Transparent Hugepages — madvise Mode

**Declared:** `hugepageMode = "madvise"`
**Current state:** Not active; kernel built with ALWAYS (`[always] madvise never`).

When active, `cachySettings.hugepage.madvise` sets:
```
TRANSPARENT_HUGEPAGE_ALWAYS = no
TRANSPARENT_HUGEPAGE_MADVISE = yes
```
Under `madvise`, hugepages are only allocated for address ranges where the application explicitly calls `madvise(MADV_HUGEPAGE)`. Applications that do this include llama.cpp (weight tensor regions), Java/JVM (heap), and some malloc implementations. The benefit over ALWAYS on a laptop: anonymous mappings that never need 2MB pages (many small allocations) don't waste memory on promotions that will be immediately split on access. Reduces idle RAM pressure from ~200–400MB typical overhead under ALWAYS mode.

---

## Kernel Build Parameters Summary

| Parameter | Value | Source |
|-----------|-------|--------|
| Kernel variant | `linux-cachyos-bore-x86_64-v3` | `kernel-cachyos/default.nix` |
| Kernel version | 7.0.10-cachyos | `linuxSources.latest` |
| `configVariant` | `linux-cachyos-bore` | CachyOS upstream |
| `cpusched` | `bore` | BORE patchset |
| `processorOpt` | `x86_64-v3` | AVX2/BMI2/FMA, no AVX-512 |
| `hzTicks` | `1000` | mkCachyKernel default |
| `tickrate` | `full` | `NO_HZ_FULL` |
| `preemptType` | `full` | `PREEMPT_DYNAMIC` + `PREEMPT` |
| `ccHarder` | `true` | `-O3` compilation |
| `lto` | `none` | GCC; binary cache compatible |
| `hugepage` | `always` | mkCachyKernel default (binary) |
| `bbr3` | `false` | Not in binary; custom build only |
| `acpiCall` | `false` | Not in binary; custom build only |
| `hardened` | `false` | — |
| `autoModules` | `true` | Maximizes module coverage |

---

## Comparison: Before and After

| Attribute | Before (6.12 LTS NixOS) | After (7.0.10 CachyOS BORE) |
|-----------|------------------------|------------------------------|
| Scheduler | EEVDF | BORE (burst-aware EEVDF) |
| I/O scheduler | bfq / mq-deadline | ADIOS |
| Timer rate | 250Hz (4ms) | 1000Hz (1ms) |
| Tickless | idle only (`NO_HZ_IDLE`) | full (`NO_HZ_FULL`) |
| Preemption | voluntary | full dynamic (`PREEMPT_DYNAMIC`) |
| Optimization | `-O2` | `-O3` |
| ISA targeting | generic x86_64 | x86_64-v3 (AVX2/BMI2/FMA) |
| ZFS package | nixpkgs `zfs` | `zfs_cachyos` (ABI-matched) |
| Kernel line | 6.12.x | 7.0.x (latest-stable) |
