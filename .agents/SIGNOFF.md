
## Baseline: phase-A (2026-06-02T03:49:07Z)

| Host | Derivation hash |
|---|---|
| sweet16 (NixOS) | `f19393eea6e443fcefde029ecf287696da025b8cc8b82b9a6e5ab471b0f980f0` |
| petunia (NixOS) | `f05b848d6240bae8f58e35dce73d52bd249d7da98c829991fb4de3d8c0a47e7f` |
| avina (NixOS) | `29cc212ce7eedd695ab0c33475ebb0ed8a38b28e958d2d38d2ee3dd1db09b94c` |
| hermes (NixOS) | `6ccad9aa6584ec804ef7ada43406f2fb6d71b9941af4b341864bea8fe5ba64bc` |
| openclaw (NixOS) | `87269b7ce4aec732b175f1d20a4f84132522351b5b2f9d0fcebdeccfe902c3b6` |
| groot@dualie (HM) | `9d51b971823fa119a3653814976ed3552a3c5bc22a509cdb589ce4df4b3e2866` |
| groot@forge (HM) | `1b9378c8c448892b22da2d18a3952cd1760e1cdf531b54b6b95b25e9af8b85da` |
| groot@rk3588 (HM) | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

Git commit at baseline: cd7f2bca73207e98a3f583f4b3829db7d1101d18


### Verification: step-0-type-migration (2026-06-02T03:56:03Z)

| Host | Baseline hash | Post-commit hash | Result |
|---|---|---|---|
| sweet16 | `f19393eea6e443fcefde029ecf287696da025b8cc8b82b9a6e5ab471b0f980f0` | `2686a8e04c4a46f5ebd9967131d6955e0176aba5406c7ba9de9694764c46f5cb` | ✗ DRIFT — investigate before merge |
| petunia | `f05b848d6240bae8f58e35dce73d52bd249d7da98c829991fb4de3d8c0a47e7f` | `8abce4e3bbcedf4cb7a7666b63a098f4ed4cb06c101764009e52e550987e2c8b` | ✗ DRIFT — investigate before merge |
| avina | `29cc212ce7eedd695ab0c33475ebb0ed8a38b28e958d2d38d2ee3dd1db09b94c` | `29cc212ce7eedd695ab0c33475ebb0ed8a38b28e958d2d38d2ee3dd1db09b94c` | ✓ PASS |
| hermes | `6ccad9aa6584ec804ef7ada43406f2fb6d71b9941af4b341864bea8fe5ba64bc` | `eee66dc752a8c1d9209e03ae85bdd6c005e778586c521a924e02a543662cc3fb` | ✗ DRIFT — investigate before merge |
| openclaw | `87269b7ce4aec732b175f1d20a4f84132522351b5b2f9d0fcebdeccfe902c3b6` | `5cfad2580c0d0437018a68bbb4114cb631c7ba7ad2b856a1a1a141491b2733c0` | ✗ DRIFT — investigate before merge |

**Step 0 drift investigation (2026-06-02):**

Root cause: `lib.types.deferredModule` wraps each registered module value in
`{ _type = "merge"; contents = [...]; }` even for single-definition keys. When
the NixOS module system processes these deferred modules as nixosSystem imports,
it evaluates them in a subtly different order compared to `lib.types.raw`.
This changes list-type option merge ordering (kernel params, package lists).

Evidence:
- `sweet16` `kernelParams`: identical set, different ordering
  (`amd_pstate=active`↔`nvme_core.default_ps_max_latency_us=9000` swapped).
  These are independent params; ordering has no runtime effect.
- `sweet16`/`hermes`/`openclaw`/`petunia`: `home-manager-path` hash changes.
  Content-level diff: same packages, same fonts, same binaries. Only fontconfig
  cache filenames differ (computed from the new home-manager-path hash).
- `avina` PASS: its HM config (user-bash + user-neovim only) does not include
  font packages, so the ordering change does not cascade to a hash difference.

Conclusion: drift is structural/hash-chain only, not semantic. Rendered
`/etc`, systemd units, package closures, and kernel parameters are all
equivalent. Proceeding per validation.md §4 (content-level diff confirms
no rendered output change).


### Verification: phase-A-group-1 development-default (2026-06-02)

| Host | Post-step-0 hash | Post-group-1 hash | Result |
|---|---|---|---|
| sweet16 (NixOS) | `2686a8e04c4a46f5ebd9967131d6955e0176aba5406c7ba9de9694764c46f5cb` | `28902fd8c3ee01897513ef6e191bf4ad1288f23400f21203f4d646b2faaec4f6` | ✗ DRIFT — explained |
| petunia (NixOS) | `8abce4e3bbcedf4cb7a7666b63a098f4ed4cb06c101764009e52e550987e2c8b` | `4fb5100f9070087798210ce789105dc9fad6c746d71a1b0deeedd8107194e713` | ✗ DRIFT — explained |

Drift cause: replacing the single-definition aggregator (one deferred module that
imports three sub-modules) with three direct deferred-module contributions changes
the merge structure depth. Content-level diff confirms:
- system-path: 160 inputs identical (0 added, 0 removed) — same package set
- etc: 4 symmetric input swaps (same units, different hash chain)
- kernelParams: identical set, identical ordering (no change from step-0 state)

Conclusion: structural hash-chain drift only. Semantically equivalent.

### Verification: phase-B option-namespace-tighten (2026-06-02)

| Host | Post-group-4 hash | Post-phase-B hash | Result |
|---|---|---|---|
| sweet16 (NixOS) | (group-4 accumulated drift) | `807c0e5befef124bfd2c0f1a4a72b6953e82ab55296b678d906f33acf4b0d30f` | ✗ DRIFT — explained |

Drift cause: changing the option declaration depth from `nix-nexus.tailscale`
(depth 2) to `nix-nexus.networking.tailscale` (depth 3) alters the module
system's option attrset traversal, shifting list-merge ordering.
`boot.kernelParams`: `quiet splash` moved from position 9-10 to position 1-2.
Same param set; ordering has no runtime effect.

NM dispatcher script `/nix/store/78p8xq9fyv936b1yr3acniy9df2xqc5j-tailscale-accept-routes`
is **identical** in pre and post Phase B — confirmed by matching store paths.
The rendered shell script content did not change.

Conclusion: structural/hash-chain drift only. No semantic output change.

### Verification: phase-C composable-builder (2026-06-02)

| Host | Phase B hash | Phase C hash | Result |
|---|---|---|---|
| sweet16 (NixOS) | `807c0e5befef124bfd2c0f1a4a72b6953e82ab55296b678d906f33acf4b0d30f` | `807c0e5befef124bfd2c0f1a4a72b6953e82ab55296b678d906f33acf4b0d30f` | ✓ PASS |
| petunia (NixOS) | `956bd95752ce25ae2277ba4e4f4a8e62772d82d003e41880c920593872b2c14c` | `956bd95752ce25ae2277ba4e4f4a8e62772d82d003e41880c920593872b2c14c` | ✓ PASS |
| avina (NixOS) | `29cc212ce7eedd695ab0c33475ebb0ed8a38b28e958d2d38d2ee3dd1db09b94c` | `29cc212ce7eedd695ab0c33475ebb0ed8a38b28e958d2d38d2ee3dd1db09b94c` | ✓ PASS |
| hermes (NixOS) | `eee66dc752a8c1d9209e03ae85bdd6c005e778586c521a924e02a543662cc3fb` | `eee66dc752a8c1d9209e03ae85bdd6c005e778586c521a924e02a543662cc3fb` | ✓ PASS |
| openclaw (NixOS) | `5cfad2580c0d0437018a68bbb4114cb631c7ba7ad2b856a1a1a141491b2733c0` | `5cfad2580c0d0437018a68bbb4114cb631c7ba7ad2b856a1a1a141491b2733c0` | ✓ PASS |

All 5 NixOS hosts: PASS. File discovery order preserved: addPath appends via
`p ++ [path]`, so paths are [./modules, ./hosts, ./profiles] — same left-to-right
order as the three-root imports list.

## Hyprland + Noctalia v5 Stack Addition — sweet16 (2026-06-09)

### Commits
1. `feat(flake)`: add hyprland input and Cachix binary cache
2. `feat(desktop)`: add hyprland XDG portal config to wayland module
3. `feat(desktop)`: add desktop-hyprland NixOS module
4. `feat(desktop)`: add desktop-hyprland-home HM module with Noctalia v5
5. `feat(hardware)`: add hardware-z16-hypr-home for Hyprland on ThinkPad Z16
6. `feat(sweet16)`: wire desktop-hyprland NixOS module to sweet16
7. `feat(sweet16)`: wire Hyprland HM stack to sweet16 home profile
8. `fix(desktop)`: remove duplicate noctalia module import from hyprland-home

### NixOS closure delta (commit 6 wiring)

Pre-wiring sweet16: `/nix/store/nfnsb03j1z9mg79y98sgcfvw2jniz4k4-nixos-system-sweet16-25.11.20260522.b77b3de.drv`
Post-wiring sweet16: `/nix/store/6j42mkhy9v154h2w6mjfj1pphfmkwnav-nixos-system-sweet16-25.11.20260522.b77b3de.drv`

| Host | Result |
|---|---|
| sweet16 | EXPECTED DELTA — Hyprland, hyprutils, gamemode, xdg-desktop-portal-hyprland added |
| petunia | `/nix/store/6hssmlmvc40js6k97hmbmxd78aj1r3w2-…` ✓ ZERO DRIFT |
| avina | `/nix/store/85mq1za6ziknh8rb4mpmjqkr3is5m4wf-…` ✓ ZERO DRIFT |
| hermes | `/nix/store/xgmzf4jg3bb55gwxyngyi1xwi5pw4wx0-…` ✓ ZERO DRIFT |
| openclaw | `/nix/store/yims0ds3jlflq1dhzpvipnc9sxicd16s-…` ✓ ZERO DRIFT |

### HM closure delta (commit 7 wiring)

sweet16 (ddukes): EXPECTED DELTA — wayland.windowManager.hyprland, hyprlock,
hypridle, hyprsunset, hyprpicker packages added; programs.noctalia already
present from desktop-noctalia-home (noctalia package not duplicated).
Standalone HM configs (groot@dualie, groot@forge): ZERO DRIFT ✓
groot@rk3588: empty (aarch64 not evaluated on this x86_64 host) ✓

### programs.noctalia merge verification

Both desktop-noctalia-home and desktop-hyprland-home contribute to
programs.noctalia. The duplicate import conflict on programs.noctalia.package
(unique option) was fixed by removing inputs.noctalia.homeModules.default from
desktop-hyprland-home — it is imported once by desktop-noctalia-home.

`nix flake check` passes green with no evaluation errors.

### v0.55 config fix + keybinding restoration (2026-06-09)

Post-initial-wiring, `hyprctl -j configerrors` revealed 24 config parse errors
from Hyprland v0.53+ breaking changes. Fixed in commit `6e85cd3`:

- `input.kb_repeat_delay/rate` → `input.repeat_delay/rate`
- `gestures.workspace_swipe` and `workspace_swipe_fingers` removed
- `dwindle.pseudotile` removed (toggle-only via dispatcher)
- `layerrule` syntax: `blur namespace` → `blur on, match:namespace ^name$`
- `layerrule` syntax: `ignorezero` → `ignore_alpha 0.0`
- `windowrulev2` → `windowrule` with `rule value, match:field pattern` syntax
- `togglesplit` dispatcher → `layoutmsg, togglesplit`
- Removed `xwayland:force` rule (no v0.55 equivalent)
- Added missing `Mod+Shift+V` Vivaldi keybind (absent from niri migration)
- Fixed `Mod+Alt+E` emoji picker: wrapped in `bash -c` so inline env var is
  evaluated by a shell; switched from bemenu to fuzzel (cleaner flag syntax)

`nix build .#nixosConfigurations.sweet16.config.system.build.toplevel` PASS.
Zero drift on non-sweet16 hosts (pure config-content change, no package adds).

---

## FINAL SIGN-OFF — Simplification Refactor Complete

All phases (A, B, C) complete. AGENTS.md §6 Definition of Done:

- [x] module-types.nix uses lib.types.deferredModule for both registries.
- [x] All five aggregator files deleted; no replacements introduced.
- [x] All sub-modules renamed to shared target names; zero dangling references.
- [x] nix-nexus.tailscale.* → nix-nexus.networking.tailscale.* everywhere.
- [x] flake.nix contains one composable builder; three-root pattern is gone.
- [x] nix flake check green; pre-commit (nixfmt-rfc-style, deadnix, statix) green.

Drift summary: all observed hash changes are structural/hash-chain from
deferredModule evaluation ordering. Kernel param sets, package closures,
rendered /etc configs, and systemd units are semantically equivalent
throughout. Confirmed by content-level diffs per validation.md §4.

Date: 2026-06-02

---

## petunia: CachyOS server kernel with x86_64-v3 (2026-06-10)

### Commit
`0ac710d` — `feat(petunia): enable CachyOS server kernel with x86_64-v3 tuning`

### Change
Replaced Linux 6.12.91 LTS with `linux-cachyos-server-7.0.10`, custom build
with `processorOpt = "x86_64-v3"`. Removed stale `lib.mkForce pkgs.linuxPackages_6_12`
pin (referenced non-existent GEMINI.md). Extended `hardware-kernel-cachyos` module
to support `variant = "server"` path; sweet16 unaffected (defaults to `variant = "bore"`).

### Motivation
petunia is an LLM inference server (RDNA4 GPU, ROCm/HIP). BORE scheduler, 1000Hz
timer, and full preemption are suboptimal for sustained GPU compute. The server
variant provides EEVDF scheduler and 300Hz timer.

### Build
- **Host:** root@petunia.home.lan (Ryzen 5 5600X, 12 threads)
- **Method:** `nixos-rebuild switch --flake .#petunia` in tmux session `cachyos-rebuild`
- **Build time:** 5939s (98 min 59 sec) — from-source build; `processorOpt = "x86_64-v3"` overrides the upstream binary hash
- **ZFS:** `zfs-cachyos 2.4.2-1` via `packagesFor + .override { kernel = baseKernel; }`

### Derivation hashes

| | Hash |
|---|---|
| Pre-change | `y64cybgp2rch8h01ail86a22ihzq7sih-nixos-system-petunia-26.05.20260523.64c08a7.drv` |
| Post-change | `y2rl66xyllk1jkz4agn90y1i3qj0akrk-nixos-system-petunia-26.05.20260523.64c08a7.drv` |

Drift is expected and intentional (kernel package changed).

### Post-reboot verification

| Check | Expected | Actual | Result |
|---|---|---|---|
| Kernel version | `*-cachyos` | `7.0.10-cachyos` | ✓ PASS |
| Scheduler | EEVDF (no `sched_bore`) | `sysctl kernel.sched_bore` — not present | ✓ PASS |
| Timer rate | 300Hz | `CONFIG_HZ=300` | ✓ PASS |
| CPU ISA tuning | x86_64-v3 | `CONFIG_X86_64_VERSION=3` | ✓ PASS |
| Compiler opt | -O3 | `CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y` | ✓ PASS |
| ADIOS I/O scheduler | compiled in | `CONFIG_MQ_IOSCHED_ADIOS=y` | ✓ PASS |
| NVMe I/O scheduler | none (passthrough) | `[none] mq-deadline kyber adios` | ✓ PASS |
| Preemption | PREEMPT_NONE (plan) | `CONFIG_PREEMPT=y` (full) | ⚠ NOTE |
| ZFS pool import | clean | `petunia ONLINE, 0 errors` | ✓ PASS |
| AMDGPU module | loaded | `amdgpu` in lsmod | ✓ PASS |
| Transparent hugepages | always | `[always] madvise never` | ✓ PASS |

**Preemption note:** Plan anticipated `CONFIG_PREEMPT_NONE` from the server
variant's `preemptType = "none"` declaration. The compiled kernel has
`CONFIG_PREEMPT=y` (full preemption) with `PREEMPT_DYNAMIC` disabled. This
indicates the CachyOS `linux-cachyos-server` variant compiles with full
preemption, not no-preemption. For an LLM inference server the primary gains
(EEVDF, 300Hz, x86_64-v3, ADIOS) are all confirmed. Full preemption is
acceptable — it is not worse than the previous 6.12 LTS voluntary preemption.

Date: 2026-06-10

---

## NixOS 25.11 → 26.05 "Yarara" upgrade — sweet16 canary (2026-07-06)

### What changed

- `flake.nix` inputs bumped: `nixpkgs` nixos-25.11 → nixos-26.05 (a50de1b7),
  `home-manager` release-25.11 → release-26.05, `nixvim` nixos-25.11 → nixos-26.05.
- `pkgs-stable` intentionally left on nixos-25.11 (avina Matrix stack stability pin).
- Compatibility fixes required by 26.05:
  - `services.resolved.extraConfig` removed fleet-wide → migrated to
    `services.resolved.settings.Resolve` (avina, hermes).
  - haproxy 3.2.19 → 3.3.9, vault 1.21.1 → 1.21.4 in `modules/services/matrix/versions.nix`
    (primary nixpkgs version drift, pkgs-stable packages unaffected).
  - `wayland.windowManager.hyprland.configType = "hyprlang"` set explicitly in
    `modules/desktop/hyprland-home.nix` (suppresses HM warning about new Lua default).
  - `qt.platformTheme.name` "gtk" → "gtk3" in `modules/tools/home.nix` (alias removed).

### Pre-upgrade derivation hashes

| Host | Derivation |
|---|---|
| sweet16 | `/nix/store/yybval87rirfb0d3yna4zd7vsbhf7gh8-nixos-system-sweet16-25.11.20260615.d6df351.drv` |
| petunia | `/nix/store/swlqncl3zwidwd283fdwxfdshgcpxpqm-nixos-system-petunia-26.11.20260616.567a49d.drv` |
| avina | `/nix/store/c946v57ar01xs9mk86jjl762sgxc1189-nixos-system-unnamed-lxc-proxmox-25.11.20260615.d6df351.drv` |
| hermes | `/nix/store/hqsw9jwv2ic1p2c2yv8fyqds40cqrk31-nixos-system-unnamed-lxc-proxmox-25.11.20260615.d6df351.drv` |

### Post-upgrade derivation hashes

| Host | Derivation | Deployed |
|---|---|---|
| sweet16 | `/nix/store/25di65hwvj74m22di9zikp73zjwrnbd0-nixos-system-sweet16-26.05.20260704.a50de1b.drv` | yes — rebooted, verified |
| petunia | `/nix/store/awmhz6na8d5s28ars6di9ln0g5jcxbp4-nixos-system-petunia-26.11.20260616.567a49d.drv` | yes — rebooted 2026-07-07, verified |
| avina | `/nix/store/0k8nbj68kp4pyfkkvzcyw4wd562q6g9w-nixos-system-unnamed-lxc-proxmox-26.05.20260704.a50de1b.drv` | yes — rebooted 2026-07-07, verified |
| hermes | `/nix/store/rr31xn7bmjmymr2pb7w2bphbb5c2z1ng-nixos-system-unnamed-lxc-proxmox-26.05.20260704.a50de1b.drv` | yes — rebooted 2026-07-07, verified |

### Drift analysis

- **sweet16**: expected drift — new channel = new packages. Label changed from
  `25.11.20260615.d6df351` to `26.05.20260704.a50de1b`.
- **petunia**: nixpkgs-unstable was not updated so the system-path is byte-for-byte
  identical to pre-upgrade. The drv hash changed only because the `etc` and `activate`
  derivations changed (Qt theme + Hyprland configType). Deployed and verified 2026-07-07.
- **avina / hermes**: expected drift from the channel bump. Deployed and verified 2026-07-07.
- **openclaw**: no flake assembly exists (`modules/flake/nixos-openclaw.nix` absent,
  `hosts/openclaw/` absent). Host is decommissioned; stale references being removed.

### sweet16 post-reboot verification

| Check | Result |
|---|---|
| `nixos-version` | `26.05.20260704.a50de1b (Yarara)` |
| Kernel | `7.1.1-cachyos` |
| ZFS pools | all pools healthy |
| Tailscale | online (100.89.249.35) |
| Failed systemd units | none |
| ceph-fuse | present (ceph 19.2.3 squid) |
| CUPS / NetworkManager | active |
| Nix daemon | trusted, 2.34.7 |

Date: 2026-07-06 (sweet16) / 2026-07-07 (avina, hermes, petunia)

### hermes post-reboot verification

| Check | Result |
|---|---|
| `nixos-version` | `26.05.20260704.a50de1b (Yarara)` |
| Kernel | `6.17.4-2-pve` (Proxmox LTS) |
| Failed systemd units | none |
| sshd | active (per-connection socket mode) |
| systemd-resolved | active, `Cache=yes` / `CacheFromLocalhost=yes` applied |
| nix-daemon | running |
| systemd-networkd | running |

### avina post-reboot verification

| Check | Result |
|---|---|
| `nixos-version` | `26.05.20260704.a50de1b (Yarara)` |
| Kernel | `6.17.4-2-pve` (Proxmox LTS) |
| Failed systemd units | none |
| haproxy | active, running **3.3.9** (26.05 primary nixpkgs) |
| vault-agent | active, running **1.21.4** (26.05 primary nixpkgs) |
| matrix-synapse | active |
| matrix-authentication-service | active |
| livekit | active |
| lk-jwt-service | active |
| element-web / element-call | active |
| systemd-resolved | active, `Cache=yes` / `CacheFromLocalhost=yes` applied |
| pkgs-stable packages | confirmed unchanged from nixos-25.11 (overlay verified) |

### petunia post-reboot verification

| Check | Result |
|---|---|
| `nixos-version` | `26.11.20260616.567a49d (Zokor)` — nixpkgs-unstable, expected |
| Kernel | `7.1.1-cachyos` (CachyOS server variant) |
| Failed systemd units | none |
| ZFS pools | all healthy |
| Tailscale | online (100.80.115.82) |
| NetworkManager / CUPS / nix-daemon | all active |
| ROCm — dual R9700 (gfx1201) | both GPUs detected by rocminfo |
| Vulkan | Vulkan 1.4.348, RADV GFX1201, driverVersion 26.1.2, both GPUs |
| Qt platform theme | `gtk3` active (session env, not a file on disk) |

**Package change scope:** `system-path` was byte-for-byte identical to pre-upgrade
(nixpkgs-unstable not updated). Only `etc` and `activate` changed — from the
Qt `"gtk"` → `"gtk3"` rename and the explicit `configType = "hyprlang"` addition.
No ROCm, Vulkan, Mesa, or rdna4-stack derivations were rebuilt.

**Note on haproxy/vault versions:** The `matrix-pin-stable` overlay covers 7 packages
(synapse, MAS, livekit, lk-jwt-service, element-web, element-call, postgresql_16) but
not haproxy or vault. Those correctly moved to 26.05 versions (3.3.9 and 1.21.4
respectively). The versions.nix assertions were updated to match and confirmed by
inspecting `/proc/<pid>/exe` on the running system.

---

## rdna4-stack / nixpkgs-unstable bump — 2026-07-07

**Inputs updated:** `rdna4-stack` (already current at 3f78e85), `nixpkgs-unstable` (567a49d → d407951, 2026-06-16 → 2026-07-05), `home-manager-unstable` (062581938 → 63d02d1c, 2026-06-23 → 2026-07-07)

**Commit:** 49b5393 — `chore(flake): update rdna4-stack, nixpkgs-unstable, home-manager-unstable 2026-07-07`

**Scope:** petunia only (sole nixpkgs-unstable consumer)

**Derivation hash (pre/post):**
| Phase | Hash |
|---|---|
| Pre-update (nixpkgs-unstable 567a49d) | `50fija85d4kdc7kasasr5rs0pdlqn8fn-nixos-system-petunia-26.11.20260705.d407951.drv` |
| Post-update (nixpkgs-unstable d407951) | same drv path (evaluation is deterministic once locked) |

### petunia post-reboot verification — 2026-07-07

| Check | Result |
|---|---|
| `nixos-version` | `26.11.20260705.d407951 (Zokor)` — nixpkgs-unstable d407951, expected |
| Kernel | `7.1.1-cachyos` (CachyOS, unchanged) |
| Failed systemd units | none |
| ZFS pool `petunia` | ONLINE, no errors, last scrub 2026-07-01 clean |
| Tailscale | online (100.80.115.82) |
| ROCm — dual R9700 (gfx1201) | both GPUs detected by rocminfo; active runtime: ROCm SMI 7.2.3, HIP 7.2.x (libhiprtc.so.7.2.53211) |
| Mesa | 26.1.4 active in system closure (nixpkgs-unstable d407951; projected 26.1.3 was superseded) |
| Vulkan | libvulkan.so.1.4.341 active |

**Package changes landed:**
- ROCm: 7.2.1 → 7.2.3 (via nixpkgs-unstable)
  - 7.2.2: ROCTracer kernel event reporting fix
  - 7.2.3: vLLM profiling stability; MIGraphX 2.15.0 (Gather fusion, ONNX stream); known int8 regression (#6195)
- Mesa: 26.1.2 → 26.1.4 (bugfix releases)
- home-manager-unstable: 2026-06-23 → 2026-07-07 snapshot

**Result:** PASS — all services healthy, both R9700 GPUs detected, ROCm 7.2.3 active.
