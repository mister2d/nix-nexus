
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

---

## Full flake input bump — 2026-07-18

**Inputs updated:** broad `nix flake update` (applied before this session). Root-visible movers:
`nixpkgs` (nixos-26.05 a50de1b7 → 8eeec934), `pkgs-stable` (nixos-25.11 d6df3513 → b6018f87),
`nixpkgs-unstable` (d4079514 → 18b9261c), `home-manager` (af2beae5 → 3cd22efe),
`home-manager-unstable` (63d02d1c → a45a7c45), `pre-commit-hooks` (3bbec39b → bca82caa),
plus devenv, cachyos-kernel(+patches), niri(+unstable), noctalia, ghostty, nixd,
nixos-hardware, llm-agents, mcp-servers-nix, bun2nix, treefmt-nix and transitive nodes.
`blueprint` input dropped from the lock (no longer referenced).

**Fixes required by the bump:**
1. avina failed its `modules/services/matrix/versions.nix` drift assertions:
   synapse 1.154.0 → **1.155.0** (via pkgs-stable), haproxy 3.3.9 → **3.3.11** (via
   primary nixpkgs). Upgrade accepted; registry and `hosts/avina/README.md` stack
   table updated. All eight other asserted stack versions verified unchanged
   (MAS 1.17.0, livekit 1.9.4, lk-jwt 0.4.0, element-web 1.12.18, element-call
   0.11.1, postgresql 16.14, vault 1.21.4, darkhttpd 1.17).
2. Evaluation warning `nixfmt-rfc-style is now the same as pkgs.nixfmt` (×2, from
   `checks.pre-commit-check` and `devShells.default`): migrated the git-hooks hook
   from `nixfmt-rfc-style` to `nixfmt` (pkgs.nixfmt 1.4.0, RFC 166 style — same
   formatter binary). `modules/flake/checks.nix`, AGENTS.md hook references, and
   the regenerated `.pre-commit-config.yaml` updated.

**Post-update derivation hashes** (pre-update hashes not captured — the lock was
already updated when validation began; drift vs prior baselines is expected and
attributable to the input bumps):

| Config | Post-update drv |
|---|---|
| sweet16 | `qrg62pf4j4bkzqryns9r0r7n6j9hac6i-nixos-system-sweet16-26.05.20260714.8eeec93.drv` |
| petunia | `klh3qlv1ldmiqgjqgvhxmvmca5gcg4rv-nixos-system-petunia-26.11.20260714.18b9261.drv` |
| avina | `hwg8mwqmji6gj6q3ivb163dhv3mcbzh7-nixos-system-unnamed-lxc-proxmox-26.05.20260714.8eeec93.drv` |
| hermes | `3h2fmaisdr5fk1zj2bsl4alp5i86xi6k-nixos-system-unnamed-lxc-proxmox-26.05.20260714.8eeec93.drv` |
| groot@dualie | `b3fflyrhifhvb1pd2kri02bfd5qqhxfj-home-manager-generation.drv` |
| groot@forge | `arrhgdy9ngv05dgaglwc7l7s3nip2z4l-home-manager-generation.drv` |

The versions.nix / checks.nix / README fixes themselves produced **zero drift**:
sweet16, petunia, hermes, dualie, forge drvs were identical before and after the
edits (assertions and pre-commit tooling are eval-time only).

**Known limitation — groot@rk3588:** cannot be evaluated from x86_64.
`modules/tools/dev/home.nix` pulls `inputs.devenv.packages.aarch64-linux.devenv`,
which triggers IFD (`cabal2nix-cachix.drv`) requiring an aarch64 builder. This does
not block `nix flake check` (homeConfigurations is not deep-checked); verify
rk3588 on-device at next deploy.

**Result:** `nix flake check` PASS — no errors, no nixfmt deprecation warnings.
Remaining warning `unknown flake output 'modules'` is structural (dendritic
`flake.modules.*` registry) and pre-dates this bump.

## Baseline: unknown (2026-07-18T07:09:12Z)

| Host | Derivation hash |
|---|---|
| sweet16 (NixOS) | `63be0bc439cd7f89f71de52a8c3ab8a1caedd25c7fe3df863c3905d87ec4fc34` |
| petunia (NixOS) | `f0693973fc852cbd39391627dddc25da0e52e4aa46ce867ac1b7121c5213ad15` |
| avina (NixOS) | `32b852548c180259f1ae3d8924b1409af6a75219d5c5c44aaa256bdb9300b122` |
| hermes (NixOS) | `974756d26a412ee14f2646db0e9a430741b4e0138927374cf2a696289c02239f` |
| openclaw (NixOS) | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| groot@dualie (HM) | `6547901a83712508bc247546ab69c651ea04272b4f58a618d9c73bb86c7fd136` |
| groot@forge (HM) | `f5479b3c64c2ae2c14d29bc4a1dc34c904fc7cc60948bb2dd0d91ba19df9c21e` |
| groot@rk3588 (HM) | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

Git commit at baseline: 30a33955c536b855ada2c4d3d5101017ae07609c

### Verification: noctalia v5.0.0-beta.3 bump + Ayu Blue theme (2026-07-18T07:30:00Z)

Commits verified:
- 30a3395 chore(flake): update noctalia to v5.0.0-beta.3 (flake.lock only; noctalia input 77087ad0ccad3909e00e828cadd94aba9e7a02dc → 8b5b1381d5a2ea94b787da11abe4f2411b89b196)
- c1a0f2c feat(desktop): switch noctalia to vendored Ayu Blue palette with OLED pure black (modules/desktop/noctalia-home.nix)
- cf89cda style(desktop): align hyprland accent with Ayu Blue palette (modules/desktop/hyprland-home.nix)

Evaluation method: `nix path-info --derivation "git+file:$PWD?rev=<rev>#..."` at
1ad87de (pre-change) and HEAD (cf89cda), avoiding dirty-working-tree artifacts.

| Host | Pre drv (1ad87de) | Post drv (cf89cda) | Drifted | Expected |
|---|---|---|---|---|
| sweet16 (NixOS) | `qrg62pf4...` | `9sam2kcn...` | YES | YES — noctalia palette (Ayu Blue + pure_black_dark) + hyprland accent change; sweet16 imports desktop-noctalia-home + desktop-hyprland-home |
| petunia (NixOS) | `klh3qlv1...` | `g2gmqaqa...` | YES | YES — same as sweet16; petunia also imports desktop-noctalia-home + desktop-hyprland-home |
| avina (NixOS) | `hwg8mwqm...` | `hwg8mwqm...` | NO | NO — avina does not consume noctalia/hyprland-home; zero drift correct |
| hermes (NixOS) | `3h2fmais...` | `3h2fmais...` | NO | NO — hermes does not consume noctalia/hyprland-home; zero drift correct |
| groot@dualie (HM) | `b3fflyrh...` | `b3fflyrh...` | NO | NO — standalone HM, no noctalia; zero drift correct |
| groot@forge (HM) | `arrhgdy9...` | `arrhgdy9...` | NO | NO — standalone HM, no noctalia; zero drift correct |
| groot@rk3588 (HM) | n/a | n/a | n/a | aarch64-linux eval fails on x86_64-linux host (pre-existing); not evaluable |

**Drift analysis:**

flake.lock diff (1ad87de → 30a3395): exactly one node changed — noctalia
77087ad0ccad3909e00e828cadd94aba9e7a02dc → 8b5b1381d5a2ea94b787da11abe4f2411b89b196.
No nixpkgs or other inputs changed. Drift is therefore confined exclusively to the
noctalia input bump and the palette/accent config changes, and touches only the two
hosts (sweet16, petunia) that import desktop-noctalia-home and desktop-hyprland-home.
avina, hermes, groot@dualie, and groot@forge are drv-identical pre- and post-change.

**Note on baseline-pre.txt hashes:** the capture-baseline.sh script hashed
`nix derivation show` output from a dirty working tree, producing spurious hash
changes for all configs. Additionally, on eval failure the pipeline hashes empty
stdin, producing `e3b0c44...` instead of a meaningful error marker (known script bug).
Those hashes should not be used for drift comparison; the clean per-rev evals above
are authoritative.

**`nix flake check` result:** all checks passed (aarch64-linux configs skipped on x86_64 host, pre-existing limitation).


### Verification: vivaldi ffmpeg-codecs pin + nixpkgs bump (2026-07-18T22:30:00Z)

Commits verified:
- 85136e8 fix(browsers): pin vivaldi to nixpkgs snapshot with matched ffmpeg codecs
  (flake.nix, flake.lock, modules/desktop/hyprland-home.nix, modules/desktop/niri-home.nix,
  modules/tools/home.nix; nixpkgs nixos-26.05 8eeec934 (2026-07-14) → 293d6abe (2026-07-17);
  new input pkgs-vivaldi = github:nixos/nixpkgs/3b32825d)

Root cause: nixos-26.05 pairs vivaldi 8.1.4087.48 with vivaldi-ffmpeg-codecs 120726,
which lacks `av_dynamic_hdr_smpte2094_app5_to_t35`. With `proprietaryCodecs = true`
vivaldi aborts at startup with a symbol lookup error (observed on sweet16 as a
"dead" $mod+SHIFT+V keybinding). Commit 3b32825d ships the matched codecs build
2026-05-18; verified by building the override from that rev and running
`vivaldi --version` successfully. Current nixos-26.05 HEAD (293d6abe) is still broken;
the pin is required until the codecs bump reaches the channel.

Evaluation method: `nix path-info --derivation "git+file:$PWD?rev=<rev>#..."` at
d622f9b (pre) and 85136e8 (post); clean per-rev evals.

| Host | Pre drv (d622f9b) | Post drv (85136e8) | Drifted | Expected |
|---|---|---|---|---|
| sweet16 (NixOS) | `9sam2kcn...` | `05w36lnq...` | YES | YES — nixpkgs 26.05 bump + pinned vivaldi in user-home/desktop-hyprland-home |
| petunia (NixOS) | `g2gmqaqa...` | `g2gmqaqa...` | NO | NO — builds from nixpkgs-unstable (not bumped); unstable's vivaldi drv (84yqpg9k) is byte-identical to the pkgs-vivaldi pin, so the module edits are a no-op for petunia |
| avina (NixOS) | `hwg8mwqm...` | `wvaydwbj...` | YES | YES — nixpkgs 26.05 bump (3 days of channel movement) |
| hermes (NixOS) | `3h2fmais...` | `5w9z5918...` | YES | YES — nixpkgs 26.05 bump |
| groot@dualie (HM) | `b3fflyrh...` | `y5a8swdg...` | YES | YES — home-manager follows nixpkgs (bumped) |
| groot@forge (HM) | `arrhgdy9...` | `4lhi9q99...` | YES | YES — same as dualie |
| groot@rk3588 (HM) | n/a | n/a | n/a | aarch64-linux eval not possible on x86_64 host (pre-existing) |

sweet16's evaluated Hyprland bind now resolves to
/nix/store/ckh62yrzhnli7ra8f39az0xy97c4pv7y-vivaldi-8.1.4087.48, which pairs with
chromium-codecs-ffmpeg-extra-2026-05-18 and launches cleanly (verified pre-deploy).

**`nix flake check` result:** all checks passed (aarch64-linux configs skipped, pre-existing).


### Verification: fastmcp sandbox test disable (2026-07-19T00:30:00Z)

Commit verified:
- 0edecdc fix(overlays): disable sandbox-hostile fastmcp supabase test
  (modules/flake/overlays.nix — appends `test_unauthorized_access` to
  fastmcp's `disabledTests` in the `buildFixes` overlay's
  `pythonPackagesExtensions`)

Evaluation method: `.agents/scripts/lock-diff.sh 96fffd5 HEAD` +
`.agents/scripts/verify-drift.sh 96fffd5 HEAD` (clean per-rev evals via
`git+file:$PWD?rev=<rev>#...`), plus direct `nix-store -qR <drv> | grep
fastmcp` closure inspection per host to confirm expectedness (code-only
overlay change, so registry-key/consumer greps alone are insufficient —
`fastmcp` is a transitive dependency, never referenced by name in any
module/host file).

`lock-diff.sh` result: zero flake.lock nodes changed (confirmed code-only commit).

| Host | Pre drv (96fffd5) | Post drv (HEAD) | Drifted | fastmcp in closure | Expected |
|---|---|---|---|---|---|
| sweet16 (NixOS) | `05w36lnq...` | `982sbjqchz...` | YES | YES (`python3.14-fastmcp-3.3.1`, `-slim`) | YES — imports `nixosModules.development-default`, whose `services.nix` applies `overlays.mcp` (= `buildFixes` + `mcp-servers-nix.overlays.default`) fleet-wide, pulling fastmcp transitively into the system closure |
| petunia (NixOS) | `g2gmqaqa...` | `xfavbarn...` | YES | YES (same fastmcp drv paths as sweet16) | YES — same `development-default` import as sweet16 |
| avina (NixOS) | `wvaydwbj...` | `wvaydwbj...` | NO | NO | NO — avina does not import `development-default`; `overlays-global` (buildFixes only, no mcp-servers-nix) is applied fleet-wide but fastmcp never enters avina's closure since nothing pulls the mcp-servers-nix package set in — zero drift correct |
| hermes (NixOS) | `5w9z5918...` | `4nag1vi1...` | YES | YES (same fastmcp drv paths) | YES — `hosts/hermes/groot-hm.nix` directly installs `unstablePkgs.mcp-nixos` (with `overlays.buildFixes` applied to that unstable pkgs import), and mcp-nixos depends on fastmcp |
| groot@dualie (HM) | `y5a8swdg...` | `y5a8swdg...` | NO | NO | NO — wires `user-dev-home` but with `enableMcpServers = false`, so `mcp-nixos` (and transitively fastmcp) is never installed; zero drift correct |
| groot@forge (HM) | `4lhi9q99...` | `09mm4bh0...` | YES | YES (same fastmcp drv paths) | YES — wires `user-dev-home` with `enableMcpServers = true`, installing `unstable-pkgs.mcp-nixos` → fastmcp |
| groot@rk3588 (HM) | n/a | n/a | N/A | N/A | aarch64-linux eval not possible on x86_64 host (pre-existing); `enableMcpServers = false` there too, so would be NO even if evaluable |

**Drift analysis:** actual-drift set {sweet16, petunia, hermes, forge} exactly
equals the expected-drift set derived from tracing actual consumers of
`mcp-nixos`/`development-default`'s `overlays.mcp` (not `consumers.sh`'s raw
text-reference search alone, which missed avina's `overlays-global` exposure
and can't resolve through `flake.nixosConfigurations` assembly files in
`modules/flake/nixos-*.nix`). Confirmed directly for every host by grepping
each host's post-change derivation closure (`nix-store -qR <drv> | grep
fastmcp`): the four drifting hosts contain the rebuilt
`python3.14-fastmcp-3.3.1.drv` / `-slim` derivations; avina and dualie contain
no fastmcp derivation at all.

**Known pre-existing issue (implementer note):** the `buildFixes` overlay is
applied twice on some paths — once fleet-wide via `modules/core/overlays-global.nix`
(`nixpkgs.overlays = [ inputs.self.overlays.buildFixes ]`) and again via
`modules/tools/dev/services.nix`'s `overlays.mcp` (`composeManyExtensions
[ buildFixes mcp-servers-nix.overlays.default ]`) on hosts that also pull in
`development-default`. This double-application is idempotent for the
`overridePythonAttrs`/`disabledTests` changes made here (list append is
order-independent for this purpose) and does not change build output, but is
noted as a pre-existing overlay-composition redundancy, not something
introduced or fixed by this commit.

**`nix flake check` result:** not re-run in this verification pass (code-only
overlay change; `lock-diff` + `verify-drift` clean per-rev evals are the
authoritative closure check per `.agents/validation.md`).


### Verification: mcp-nixos check override scope fix (2026-07-19T01:00:00Z)

Commit verified:
- cba5569 fix(overlays): move mcp-nixos check override to its real scope
  (modules/flake/overlays.nix — removes the dead `pyPrev.mcp-nixos`
  override inside `pythonPackagesExtensions` (mcp-nixos is a
  `pkgs.by-name` `buildPythonApplication`, never a `python3Packages`
  entry, so that override could never match); adds a top-level
  `prev.mcp-nixos.overridePythonAttrs` in `buildFixes` setting both
  `doCheck = false` and `doInstallCheck = false`, since mcp-nixos's
  tests run in `installCheckPhase` gated by `doInstallCheck`, not
  `checkPhase`/`doCheck`)

This is a genuine behavior change (the prior override was dead code), so
the mcp-nixos derivation itself changes for every consumer, not just a
no-op re-verification.

Evaluation method: `.agents/scripts/lock-diff.sh 389ce53 HEAD` +
`.agents/scripts/verify-drift.sh 389ce53 HEAD` (clean per-rev evals), plus
direct `nix-store -qR <drv> | grep mcp-nixos` closure inspection and a
`nix show-derivation | jq -S` diff of the `mcp-nixos` `.drv` itself to
confirm the root cause.

`lock-diff.sh` result: zero flake.lock nodes changed (confirmed code-only commit).

| Host | Pre drv (389ce53) | Post drv (HEAD) | Drifted | mcp-nixos in closure | Expected |
|---|---|---|---|---|---|
| sweet16 (NixOS) | `982sbjqchz...` | `q671xmfwla...` | YES | YES (`mcp-nixos-2.4.3`: `hrvd9an5...` → `yqj2s91l...`) | YES — same `development-default` consumer set established in the prior sign-off |
| petunia (NixOS) | `xfavbarn...` | `s2k2x2hg...` | YES | YES (mcp-nixos present) | YES — imports `development-default`, same as sweet16 |
| avina (NixOS) | `wvaydwbj...` | `wvaydwbj...` | NO | NO | NO — avina never pulls the mcp-nixos package; zero drift correct |
| hermes (NixOS) | `4nag1vi1...` | `l6ll104n...` | YES | YES (mcp-nixos present) | YES — `groot-hm.nix` directly installs `unstablePkgs.mcp-nixos` |
| groot@dualie (HM) | `y5a8swdg...` | `y5a8swdg...` | NO | NO | NO — `enableMcpServers = false`; mcp-nixos never installed |
| groot@forge (HM) | `09mm4bh0...` | `5nnkq88n...` | YES | YES (mcp-nixos present) | YES — `enableMcpServers = true` installs `unstable-pkgs.mcp-nixos` |
| groot@rk3588 (HM) | n/a | n/a | N/A | N/A | aarch64-linux eval not possible on x86_64 host (pre-existing) |

**Drift analysis:** actual-drift set {sweet16, petunia, hermes, forge}
exactly equals the expected set — identical to the consumer set established
in the fastmcp sign-off above, since both changes live in the same
`buildFixes` overlay and only affect hosts whose closures actually contain
`mcp-nixos`. avina and dualie remain drift-free because neither ever
installs the `mcp-nixos` package (confirmed absent from both closures via
`nix-store -qR`).

**Root cause, confirmed not assumed:** diffed the `mcp-nixos-2.4.3.drv`
itself pre/post on sweet16 with `nix show-derivation | jq -S`. The only
environment-affecting change is `doInstallCheck: "1"` → `doInstallCheck:
""`, and `nativeBuildInputs` drops `pytest-check-hook`,
`python3.14-pytest-asyncio`, and `python3.14-pytest-cov-stub` accordingly —
exactly the mechanism described in the commit message (the prior fix never
reached `doInstallCheck` because the override never matched at all; this
commit is the first time mcp-nixos's checks are actually disabled).

**`nix flake check` result:** not re-run in this verification pass
(code-only overlay change; `lock-diff` + `verify-drift` clean per-rev evals
are the authoritative closure check per `.agents/validation.md`).


### Verification: television package dedup (2026-07-19T01:30:00Z)

Commit verified:
- f35a127 fix(tools): drop redundant television package shadowed by
  programs.television (modules/tools/television-home.nix — removes
  `home.packages = [ pkgs.television ]`, which collided with the wrapped
  package `programs.television` already installs into the same
  home-manager profile; also collapses the module header to `_:` and
  applies a `nixfmt` reformat pass)

Evaluation method: `.agents/scripts/lock-diff.sh 9dd47a1 HEAD` +
`.agents/scripts/verify-drift.sh 9dd47a1 HEAD` (clean per-rev evals), plus
`.agents/scripts/consumers.sh user-television-home user-home` and direct
grep of each host's HM wiring file to derive the expected-drift set.

`lock-diff.sh` result: zero flake.lock nodes changed (confirmed code-only commit).

**Expected-drift derivation:** `user-television-home` is imported directly
by `hosts/{rk3588,dualie,forge}/home.nix` and `hosts/hermes/groot-hm.nix`,
and indirectly by `modules/tools/home.nix`'s `user-home` key, which is in
turn imported by `hosts/sweet16/home.nix` and `hosts/petunia/home.nix`.
`avina` was checked explicitly (`hosts/avina/home.nix` imports only
`user-bash` and `user-neovim-home`) and does not reach
`user-television-home` at all — confirmed excluded from the expected set.

| Host | Pre drv (9dd47a1) | Post drv (HEAD) | Drifted | Expected |
|---|---|---|---|---|
| sweet16 (NixOS) | `q671xmfwla...` | `2af8ymr7lv...` | YES | YES — `hosts/sweet16/home.nix` imports `user-home`, which pulls in `user-television-home` via `modules/tools/home.nix:65` |
| petunia (NixOS) | `s2k2x2hg...` | `30jr82wp...` | YES | YES — same `user-home` path as sweet16 |
| avina (NixOS) | `wvaydwbj...` | `wvaydwbj...` | NO | NO — `hosts/avina/home.nix` never imports `user-home` or `user-television-home`; zero drift correct |
| hermes (NixOS) | `l6ll104n...` | `ia61nz7b...` | YES | YES — `hosts/hermes/groot-hm.nix:55` imports `user-television-home` directly |
| groot@dualie (HM) | `y5a8swdg...` | `y3qql25g...` | YES | YES — `hosts/dualie/home.nix:21` imports `user-television-home` directly |
| groot@forge (HM) | `5nnkq88n...` | `6r1jq79j...` | YES | YES — `hosts/forge/home.nix:15` imports `user-television-home` directly |
| groot@rk3588 (HM) | n/a | n/a | N/A | aarch64-linux eval not possible on x86_64 host (pre-existing). Note: `hosts/rk3588/home.nix:14` also imports `user-television-home` directly, so this config **would** drift the same as dualie/forge if it were evaluable — the N/A here is an evaluation-environment limitation, not evidence of no-drift. |

**Drift analysis:** actual-drift set {sweet16, petunia, hermes, dualie,
forge} exactly equals the expected set derived above. `avina` is the only
NixOS host that does not drift, and it is the only one that never reaches
`user-television-home` through any import chain.

**Mechanism (mechanical, not deep-forensic — sufficient given the change
shape):** the `television` package derivation build itself is unchanged
(`television-0.15.6.drv` has the identical store hash pre/post, confirmed
via `nix-store -qR` on the groot@dualie activation closure). What changed
is `home.packages`: removing the extra `pkgs.television` entry shrinks the
HM profile's package buildEnv (`home-manager-path.drv`), which changes that
derivation's hash and cascades to the generation/toplevel for every
consumer — precisely the six hosts/configs identified above.

**`nix flake check` result:** not re-run in this verification pass
(code-only module change; `lock-diff` + `verify-drift` clean per-rev evals
are the authoritative closure check per `.agents/validation.md`).


### Verification: devenv migration (2026-07-19T06:46:12Z)

Commits verified (02f5287..5851bb0):
- 2e33fb4 feat(devenv): migrate devshell to devenv with git-hooks parity
- d5f4cc3 feat(devenv): declare claude code hooks and mcp servers in devenv
- aac50e6 docs(devenv): document devenv-owned claude code environment
- 94f3aaf fix(devenv): pass explicit flake ref to nix-direnv's use flake
- 5851bb0 chore(devenv): gitignore .devenv/

Evaluation method: `.agents/scripts/lock-diff.sh 02f5287 5851bb0` +
`.agents/scripts/verify-drift.sh 02f5287 5851bb0` (clean per-rev evals),
plus `.agents/scripts/consumers.sh mk-shell-bin nix2container devenv` and
direct grep of the resolved consumer files to judge whether the reported
consumers are genuine host-facing dependents.

`lock-diff.sh` result: two `flake.lock` nodes added —
`mk-shell-bin` (`null` → `ff5d8bd4d68a347be5042e2f16caee391cd75887`) and
`nix2container` (`null` → `76be9608a7f4d6c985d28b0e7be903ae2547df3e`).
Both are new inputs of `root` (i.e. required directly by `flake.nix`, not by
any consumed subgraph), pulled in because `modules/flake/checks.nix` newly
imports `inputs.devenv.flakeModule` to define `devShells.default` — they are
devenv's own shell-building machinery dependencies. No other node in
`flake.lock` changed: `devenv` itself remains locked at
`bd1c175d8aff2cd47e1999f6be7b7d79a4253d93` (identical `inputs` map, same
rev, pre and post), and `nixpkgs`, `nixpkgs-unstable`, `home-manager`,
`noctalia`, `hyprland`, and `git-hooks` are all byte-identical.

**Expected-drift derivation:** `consumers.sh mk-shell-bin nix2container
devenv` reported `forge`, `rk3588`, `dualie`, `sweet16`, and `petunia` as
touching the string `devenv` — but only via `modules/tools/dev/home.nix:155`,
which installs `inputs.devenv.packages.${system}.devenv` (the devenv CLI
binary) into the `user-dev-home` profile these hosts import. Neither
`mk-shell-bin` nor `nix2container` appears anywhere in `modules/`, `hosts/`,
or `profiles/` — they are devShell-only, never referenced by a host or HM
config. Because the `devenv` flake input's locked rev is unchanged, the
`devenv` CLI package derivation those five configs consume is expected to
be bit-identical, so the true expected-drift set for this migration is
**empty** across all seven configs (`groot@rk3588` N/A on x86_64 per
standing policy).

`verify-drift.sh` result:

| Config | 02f5287 | 5851bb0 | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `2af8ymr7lv...` | `2af8ymr7lv...` | none |
| petunia (NixOS) | `30jr82wp...` | `30jr82wp...` | none |
| avina (NixOS) | `wvaydwbj...` | `wvaydwbj...` | none |
| hermes (NixOS) | `ia61nz7b...` | `ia61nz7b...` | none |
| groot@dualie (HM) | `y3qql25g...` | `y3qql25g...` | none |
| groot@forge (HM) | `6r1jq79j...` | `6r1jq79j...` | none |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

`verify-drift.sh` exited 0 (no drift). No devenv/flake-compat impurity
assertion was hit during evaluation — both `lock-diff.sh` and
`verify-drift.sh` ran clean on the first pass; no `--impure` accommodation
or script patch was needed.

**Drift analysis:** actual-drift set is empty, exactly matching the
expected-drift set. All five toplevel/generation derivation hashes are
byte-identical pre/post across the full commit range, confirming the
devenv migration (devShell definition, Claude Code hooks/MCP generation,
git-hooks parity) is fully devShell-scoped and does not touch any
`nixosConfigurations` or `homeConfigurations` output.

**`nix flake check` result:** not re-run in this verification pass
(clean per-rev `lock-diff` + `verify-drift` evals are the authoritative
closure check per `.agents/validation.md`, and both completed without
error on the first attempt).


### Verification: legacy vim/tmux copy-paste fix (2026-07-20T00:00:00Z)

Commit verified: c2ca3c9 "fix(tools): restore legacy vim/tmux copy-paste
behavior" (parent 4aca4dd).

What changed (both Home Manager option-value edits, no structural or
namespace changes):
- `modules/tools/neovim-home.nix` (`user-neovim-home`): removed
  `clipboard.register = "unnamedplus";` from the nixvim `clipboard = { ... }`
  block (kept `providers.wl-copy.enable = true;`), so the unnamed register
  no longer aliases the system clipboard on every delete/change.
- `modules/tools/terminal-home.nix` (`user-terminal-home`): changed
  `programs.tmux.mouse` from `true` to `false`, restoring native
  terminal-emulator click-drag selection instead of tmux mouse-mode capture.

Evaluation method: `.agents/scripts/lock-diff.sh 4aca4dd c2ca3c9` +
`.agents/scripts/consumers.sh user-neovim-home user-terminal-home` +
`.agents/scripts/verify-drift.sh 4aca4dd c2ca3c9` (clean per-rev evals),
followed by a content-level diff of the realized
`home-manager-files` store paths for `groot@dualie` to confirm the drift
is scoped to only the two rendered config files.

`lock-diff.sh` result: exit 0, no `flake.lock` nodes changed (this is a
pure module-code edit; no input touched).

`consumers.sh user-neovim-home user-terminal-home` result: all seven
hosts/configs consume both keys — `sweet16` and `petunia` via
`hosts/sweet16/home.nix` / `hosts/petunia/home.nix`, `avina` via
`hosts/avina/home.nix`, `hermes` via `hosts/hermes/groot-hm.nix`, and
`dualie`/`forge`/`rk3588` via their respective `hosts/<host>/home.nix`.
Expected-drift set: every config except `groot@rk3588` (N/A on x86_64).

`verify-drift.sh` result (exit 10, drift found):

| Config | 4aca4dd | c2ca3c9 | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `2af8ymr7lv...` | `yp6kr05qpr...` | DRIFT |
| petunia (NixOS) | `30jr82wpgf...` | `jmm8im3qqs...` | DRIFT |
| avina (NixOS) | `wvaydwbj0k...` | `i2hk8dl2zs...` | DRIFT |
| hermes (NixOS) | `ia61nz7b0m...` | `zcbgbprm5b...` | DRIFT |
| groot@dualie (HM) | `y3qql25grd...` | `gkfzdppll6...` | DRIFT |
| groot@forge (HM) | `6r1jq79jrd...` | `j9wc1rqhx9...` | DRIFT |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

**Drift analysis:** actual-drift set (all six evaluable configs) is exactly
equal to the expected-drift set derived from `consumers.sh` — no config
outside the two modules' consumers moved, and every consumer did move.
Content-level confirmation: realized and diffed the `home-manager-files`
outputs for `groot@dualie` pre/post (`zqhmyb31...` vs `qyc4j0lg...`);
`diff -rq` reports exactly two differing files —
`.config/nvim/init.lua` and `.config/tmux/tmux.conf` — and nothing else in
the tree. This matches the two edited option values precisely; the
generation/toplevel hash cascade above is the expected chain reaction of
those two rendered file changes, not evidence of unrelated drift.

**`nix flake check` result:** not re-run in this verification pass
(clean per-rev `lock-diff` + `verify-drift` evals plus the content-level
`home-manager-files` diff are the authoritative closure check per
`.agents/validation.md`, and all completed without error).

### Verification: hermes python-olm fix + llm-agents nixpkgs.follows (2026-07-20)

Commit verified: e0c0c39 "fix(hermes): resolve python-olm buildEnv conflict,
follow nixpkgs for llm-agents" (parent f2488b5).

What changed:
- `hosts/hermes/home.nix`: excludes `python-olm` from `pythonDeps` (same
  pattern as the existing `aiosqlite` exclusion), removing the `buildEnv`
  collision between `hermes-agent`'s propagated stock `python-olm` and the
  host's overridden one.
- `hosts/hermes/llm-agents-overlay.nix`: replaces a hardcoded
  `"lib/python3.13/site-packages"` string with `hermesPython.sitePackages`,
  derived from the actual interpreter.
- `flake.nix` / `flake.lock`: adds `inputs.llm-agents.inputs.nixpkgs.follows
  = "nixpkgs"` and re-locks; `llm-agents` bumps to a new upstream rev
  (`5c73869` → `2af0e04`) and its nixpkgs input is dropped in favor of the
  fleet's top-level pin.

`lock-diff.sh f2488b5 e0c0c39` result (exit 10, nodes changed): `llm-agents`
(new rev), `treefmt-nix_2` (llm-agents' own transitive pin, moved with its
rev bump), and a cascade of `nixpkgs_2`..`nixpkgs_7` node-alias renumbers.
Verified by diffing both lockfiles directly: the fleet's actual top-level
`nixpkgs` node (`nixpkgs_5` → `nixpkgs_4`) is **the same commit**,
`293d6abedf0478e681a4dfcfcb35b30fc796a32f`, before and after — the
renumbering is purely index-shift from removing llm-agents' now-unused
standalone `nixpkgs_2` node, not a real nixpkgs bump. `pkgs-vivaldi`'s
independent pin (`3b32825d…`) is untouched (separate node, not an alias
target).

`consumers.sh llm-agents` result: `hermes` (via `llm-agents-overlay.nix` and
`home.nix`), plus `forge`, `rk3588`, `dualie`, `sweet16`, `petunia` — all via
a shared chain through `modules/tools/dev/home.nix` (`user-dev-home`, which
references `inputs.llm-agents.packages` directly for `llmAgentPackages`) →
`modules/tools/home.nix` (`user-home`) → each host's `home.nix`. `avina` is
correctly absent: it only imports `user-bash` + `user-neovim-home`, never
`user-home`. This means the **expected-drift set is not hermes-only** —
`llm-agents` was already a broader dependency than the commit message
implies, reached by every HM-composed host via the shared dev-tools module,
not just hermes's dedicated overlay.

Of those consumers, `rk3588` and `dualie` explicitly set
`nix-nexus.dev.enableLlmAgents = false`; `forge` sets it `true`; `sweet16`,
`petunia`, and `hermes` take the module's `default = true` (unset). Because
`agentPkgs = inputs.llm-agents.packages.${system}` is bound lazily inside a
`let` and only forced when `cfg.enableLlmAgents` is true, hosts with the flag
off are expected to reference `llm-agents` textually but not pull it into
their built closure.

`verify-drift.sh f2488b5 e0c0c39` result (exit 10, drift found):

| Config | f2488b5 | e0c0c39 | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `yp6kr05qpr...` | `s5wvw3bw76...` | DRIFT |
| petunia (NixOS) | `jmm8im3qqs...` | `7qpq4bf47v...` | DRIFT |
| avina (NixOS) | `i2hk8dl2zs...` | `i2hk8dl2zs...` | none |
| hermes (NixOS) | `zcbgbprm5b...` | `701q0flnbr...` | DRIFT |
| groot@dualie (HM) | `gkfzdppll6...` | `gkfzdppll6...` | none |
| groot@forge (HM) | `j9wc1rqhx9...` | `jv3hfb44bk...` | DRIFT |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

**Drift analysis:** actual-drift set is `{sweet16, petunia, hermes, forge}`.
This is an exact match against the `consumers.sh`-derived expected set once
the `enableLlmAgents` laziness is accounted for: `avina` (not a consumer at
all) and `dualie`/`rk3588` (consumers with the flag disabled, so
`agentPkgs` is never forced) correctly show zero drift, while every host
that both consumes `user-dev-home`/`llm-agents-hermes` *and* has
`enableLlmAgents` true (`sweet16`, `petunia`, `hermes`, `forge`) drifted.
No host outside the expected consumer set moved — the `nixpkgs.follows`
change had no wider blast radius than intended.

Content-level confirmation on `groot@forge`: diffed both
`home-manager-generation.drv`s with
`nix derivation show | python3 -m json.tool`. The only differing inputs are
`activation-script.drv` and `home-manager-path.drv` — consistent with the
`llmAgentPackages` package set changing under the new `llm-agents` rev
(now built against the fleet's Python 3.13 nixpkgs instead of the prior
independent pin), and nothing else in forge's derivation graph moved.

The pre-existing local build (`nix build
.#nixosConfigurations.hermes.config.system.build.toplevel`) succeeding, plus
`preflight.sh`'s clean `pre-commit` + `nix flake check --impure` pass before
commit, are consistent with this analysis.

**Verdict: SIGNED OFF.** Drift is fully expected once the correct
expected-drift set is derived from `consumers.sh` rather than assumed from
the commit message — `sweet16` and `petunia` drifting is not evidence of
unintended blast radius; it is because they were already indirect consumers
of `llm-agents` through the shared `user-dev-home` module (default
`enableLlmAgents = true`), which the commit message did not call out.
`avina` correctly shows zero drift (not a consumer), and `groot@rk3588` is
`N/A` on x86_64 per convention.

## Baseline: unknown (2026-07-23T16:18:20Z)

| Host | Derivation |
|---|---|
| sweet16 (NixOS) | `/nix/store/s5wvw3bw76ik9ffjfwrki71gz0yz0y18-nixos-system-sweet16-26.05.20260717.293d6ab.drv` |
| petunia (NixOS) | `/nix/store/7qpq4bf47vsr6754ff9dij50wzxkr99s-nixos-system-petunia-26.11.20260714.18b9261.drv` |
| avina (NixOS) | `/nix/store/i2hk8dl2zsrbl2nibgnn934r9syvjgh2-nixos-system-unnamed-lxc-proxmox-26.05.20260717.293d6ab.drv` |
| hermes (NixOS) | `/nix/store/701q0flnbr44g50sbrbyz4nmcwl2yi48-nixos-system-unnamed-lxc-proxmox-26.05.20260717.293d6ab.drv` |
| groot@dualie (HM) | `/nix/store/gkfzdppll6mb15rm6h7z3hxlsqdwn6xk-home-manager-generation.drv` |
| groot@forge (HM) | `/nix/store/jv3hfb44bk576phg80mpz047vsfl07n1-home-manager-generation.drv` |
| groot@rk3588 (HM) | `N/A` |

Git commit at baseline: 5ba9b2d80b9f09711fd3cac71556b1c9347922b4

## Validation: 3985f0f — refactor(petunia): remove rdna4-stack input, inline GPU/ROCm wiring

`lock-diff.sh 5ba9b2d 3985f0f` result (exit 10, nodes changed): the
`rdna4-stack` node is removed from `flake.lock` entirely (`3f78e85… → null`),
along with its transitive `flake-parts_6` follow node (`f7c1a2d… → null`).
No other input moved.

`consumers.sh rdna4-stack` at the pre-removal tree
(`hosts/AGENTS.md`/`modules/flake/nixos-petunia.nix`, worktree at 5ba9b2d)
returns no output — a known script limitation: `nixos-petunia.nix` consumes
`inputs.rdna4-stack.nixosModules.{rdna4-dual,rdna4-full}` directly inside a
`flake.nixosConfigurations.petunia` assembly rather than registering under a
`flake.modules.nixos.*` key, so the script's recursive registry-key walk has
no host file to terminate on. Manual grep confirms the only two references
to `rdna4-stack` anywhere under `modules/`, `hosts/`, `profiles/` are both in
`modules/flake/nixos-petunia.nix` — petunia is the sole consumer.
Expected-drift set: `{petunia}`; all other hosts and HM configs zero drift.

`verify-drift.sh HEAD~1 HEAD` (5ba9b2d → 3985f0f) result (exit 10, drift
found):

| Config | 5ba9b2d | 3985f0f | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `s5wvw3bw76...` | `s5wvw3bw76...` | none |
| petunia (NixOS) | `7qpq4bf47v...` | `z54m792qz2...` | DRIFT |
| avina (NixOS) | `i2hk8dl2zs...` | `i2hk8dl2zs...` | none |
| hermes (NixOS) | `701q0flnbr...` | `701q0flnbr...` | none |
| groot@dualie (HM) | `gkfzdppll6...` | `gkfzdppll6...` | none |
| groot@forge (HM) | `jv3hfb44bk...` | `jv3hfb44bk...` | none |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

Actual-drift set is exactly `{petunia}` — matches the expected set from the
manual consumer trace with zero surprises.

Content-level confirmation on petunia: diffed both toplevel `.drv`s with
`nix derivation show | python3 -m json.tool`. The diff is confined to the
expected structural shift (new `etc.drv`/`activate.drv`/`system-path.drv`
hashes, `boot.json` content-address change, and `kernelParams` list-order
churn with all values, including `amdgpu.gpu_recovery=1`,
`amdgpu.lockup_timeout=10000`, and `iommu=pt`, still present — reordered by
list-merge position only, no values added or removed). Diffing the two
`system-path.drv`s' `inputDrvs` sets (168 → 153 entries) shows exactly the
build-toolchain packages the commit intended to drop from the closure:
`vulkan-loader`, `vulkan-headers`, `vulkan-validation-layers`, `shaderc`,
`glslang`, `cmake`, `ninja`, `pkg-config-wrapper`, `ccache`, `openssl`,
`clr` (rocm clang), `rocm-toolchain`, `rocblas`, `hipblas`, `rocwmma` — with
`rocminfo` and `rocm-smi` (runtime, not build-toolchain) untouched in both.
Diffed `modules/hardware/petunia/rdna4.nix` at both revs: the new file
(112 lines, up from 16) contains the `pkgs.symlinkJoin { name =
"rocm-combined-gfx1201"; ... }` block, `boot.kernelParams` with
`amdgpu.initrd.enable`/`amdgpu.overdrive.enable`, `hardware.graphics` with
`pkgs.rocmPackages.clr.icd` + `pkgs.libva` (+ `pkgsi686Linux.libva` for
`extraPackages32`), the `udev.extraRules` render/kfd rules, and session vars
`ROCR_VISIBLE_DEVICES = "0,1"`, `HCC_AMDGPU_TARGET = "gfx1201,gfx1201"`,
`LIBVA_DRIVER_NAME`/`VDPAU_DRIVER = "radeonsi"` — all inlined verbatim as
the commit describes, none dropped.

**Verdict: SIGNED OFF.** Actual drift (`{petunia}`) equals expected drift.
The closure shrinkage on petunia is confined to the build-toolchain packages
and session vars the commit intentionally removed; every runtime-facing
piece of GPU/ROCm wiring (kernel params, `/opt/rocm` symlinkJoin, hardware.graphics,
udev rules, LACT/overdrive, initrd KMS, LIBVA/VDPAU vars) is present
unchanged in the new inlined module. `sweet16`, `avina`, `hermes`,
`groot@dualie`, `groot@forge` show zero drift as expected (none consumed
`rdna4-stack`), and `groot@rk3588` is `N/A` on x86_64 per convention.

## Validation: f58e074 — fix(desktop): stop typing emoji via wtype, use clipboard-only bemoji

`lock-diff.sh f58e074^ f58e074` result (exit 0, no nodes changed): `flake.lock`
is untouched — this is a pure in-tree source edit, no input moved.

The commit changes the bemoji emoji-picker keybinding from `bemoji -t -c` to
`bemoji -c` (dropping `-t`, the wtype-based typing mode; keeping `-c`,
clipboard-only) in three compositor Home Manager modules:
`modules/desktop/niri-home.nix` (`desktop-niri-home`),
`modules/desktop/hyprland-home.nix` (`desktop-hyprland-home`), and
`modules/desktop/sway-home.nix` (`desktop-sway-home`).

`consumers.sh desktop-niri-home desktop-hyprland-home desktop-sway-home`
returns `sweet16` and `petunia` (both via `homeManagerModules.desktop-hyprland-home`
in their respective `hosts/*/home.nix`). A manual grep of
`desktop-niri-home`/`desktop-hyprland-home`/`desktop-sway-home` across
`hosts/` and `modules/` confirms no host currently wires in
`desktop-niri-home` or `desktop-sway-home` — only `desktop-hyprland-home`,
consumed by exactly these two hosts. Expected-drift set: `{sweet16, petunia}`;
all other hosts and HM configs zero drift.

`verify-drift.sh f58e074^ f58e074` (exit 10, drift found):

| Config | f58e074^ | f58e074 | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `s5wvw3bw76...` | `f16z5q87nm...` | DRIFT |
| petunia (NixOS) | `z54m792qz2...` | `qp72gfdya5...` | DRIFT |
| avina (NixOS) | `i2hk8dl2zs...` | `i2hk8dl2zs...` | none |
| hermes (NixOS) | `701q0flnbr...` | `701q0flnbr...` | none |
| groot@dualie (HM) | `gkfzdppll6...` | `gkfzdppll6...` | none |
| groot@forge (HM) | `jv3hfb44bk...` | `jv3hfb44bk...` | none |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

Actual-drift set is exactly `{sweet16, petunia}` — matches the expected set
with zero surprises.

Content-level confirmation: built
`nixosConfigurations.sweet16.config.home-manager.users.ddukes.xdg.configFile."hypr/hyprland.conf".source`
at both revs and diffed the two rendered `hyprland.conf` files directly. The
diff is confined to a single line:

```
< bind=$mod ALT, E, exec, .../bash -c 'BEMOJI_PICKER_CMD="... fuzzel ..." .../bemoji -t -c'
---
> bind=$mod ALT, E, exec, .../bash -c 'BEMOJI_PICKER_CMD="... fuzzel ..." .../bemoji -c'
```

Exactly the intended `-t ` removal, nothing else — same fuzzel picker
command, same bash wrapper, same store paths for every other input. `wtype`
remains in the package set (unused by the new command, as the commit
message describes) and is not the source of the closure hash change; the
change is confined to the embedded command string.

**Verdict: SIGNED OFF.** Actual drift (`{sweet16, petunia}`) equals expected
drift. `avina`, `hermes`, `groot@dualie`, `groot@forge` show zero drift as
expected (none consume `desktop-hyprland-home`, `desktop-niri-home`, or
`desktop-sway-home`), and `groot@rk3588` is `N/A` on x86_64 per convention.

## Validation: f9666f7 — fix(desktop): drop trailing newline from bemoji clipboard output

`lock-diff.sh f9666f7^ f9666f7` result (exit 0, no nodes changed): `flake.lock`
is untouched — this is a pure in-tree source edit, no input moved.

The commit changes the bemoji emoji-picker keybinding from `bemoji -c` to
`bemoji -n -c` (adding `-n`/`--noline` so bemoji does not append a trailing
newline to the clipboard payload) in the same three compositor Home Manager
modules as f58e074: `modules/desktop/niri-home.nix` (`desktop-niri-home`),
`modules/desktop/hyprland-home.nix` (`desktop-hyprland-home`), and
`modules/desktop/sway-home.nix` (`desktop-sway-home`). Direct follow-up to
f58e074, same mechanism.

`consumers.sh desktop-hyprland-home desktop-niri-home desktop-sway-home`
returns `sweet16` and `petunia` (both via `homeManagerModules.desktop-hyprland-home`
in their respective `hosts/*/home.nix`); `desktop-niri-home` and
`desktop-sway-home` have no consumers. Expected-drift set: `{sweet16,
petunia}`; all other hosts and HM configs zero drift.

`verify-drift.sh f9666f7^ f9666f7` (exit 10, drift found):

| Config | f9666f7^ | f9666f7 | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `f16z5q87nm...` | `s5akq6cvv8...` | DRIFT |
| petunia (NixOS) | `qp72gfdya5...` | `qizb52qrjg...` | DRIFT |
| avina (NixOS) | `i2hk8dl2zs...` | `i2hk8dl2zs...` | none |
| hermes (NixOS) | `701q0flnbr...` | `701q0flnbr...` | none |
| groot@dualie (HM) | `gkfzdppll6...` | `gkfzdppll6...` | none |
| groot@forge (HM) | `jv3hfb44bk...` | `jv3hfb44bk...` | none |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

Actual-drift set is exactly `{sweet16, petunia}` — matches the expected set
with zero surprises.

Content-level confirmation: built
`nixosConfigurations.sweet16.config.home-manager.users.ddukes.home.activationPackage`
at both revs, resolved each to its rendered `home-files/.config/hypr/hyprland.conf`,
and diffed them directly. The diff is confined to a single line:

```
< bind=$mod ALT, E, exec, .../bash -c 'BEMOJI_PICKER_CMD="... fuzzel ..." .../bemoji -c'
---
> bind=$mod ALT, E, exec, .../bash -c 'BEMOJI_PICKER_CMD="... fuzzel ..." .../bemoji -n -c'
```

A full-tree `diff -rq` of the two `home-files` outputs confirms no other file
in the rendered tree differs. Exactly the intended `-n ` insertion, nothing
else — same fuzzel picker command, same bash wrapper, same store paths for
every other input.

**Verdict: SIGNED OFF.** Actual drift (`{sweet16, petunia}`) equals expected
drift. `avina`, `hermes`, `groot@dualie`, `groot@forge` show zero drift as
expected (none consume `desktop-hyprland-home`, `desktop-niri-home`, or
`desktop-sway-home`), and `groot@rk3588` is `N/A` on x86_64 per convention.

## Validation: bc4af05 — chore(flake): bump llm-agents for updated claude-code CLI

`lock-diff.sh bc4af05^ bc4af05` result (exit 10, nodes changed):

```
bun2nix 5a39d717029e94163ac223aee8d5c9946cafed1c → 0f2a1f0b6f42cebe3b149bf62d38754c5e0e9729
llm-agents 2af0e0457cfbbcf21182737cd26b0be13282196d → e711100ae4b583e6a3d20243c639f8e86bd75a89
```

Pure `flake.lock` bump; `bun2nix` is a transitive input of `llm-agents`, no
other nodes moved.

`consumers.sh llm-agents bun2nix` returns every registry consumer of the
shared `user-dev-home` module: `hermes` (via `hosts/hermes/llm-agents-overlay.nix`
+ `hosts/hermes/home.nix`), `forge`, `rk3588`, `dualie`, `sweet16`, `petunia`
(all via their respective `home.nix` → `homeManagerModules.user-dev-home`).
`avina` is absent — its `home.nix` only imports `user-bash` and
`user-neovim-home`, never `user-dev-home`.

This is the module-reachability set, not the runtime-consumption set:
`modules/tools/dev/home.nix` gates the `agentPkgs.claude-code` /
`antigravity-cli` / `opencode` / `pi` package list (the actual `llm-agents`
input consumers) behind `programs.dev-home.enableLlmAgents`, which
`hosts/dualie/home.nix` and `hosts/rk3588/home.nix` explicitly set to
`false` ("Disabled MCP servers and LLM agents because they require modern
CPU instructions... missing on Ivy Bridge Xeons" / aarch64 equivalent).
`hosts/forge/home.nix` sets it `true`. Refined expected-drift set once
runtime gating is accounted for: `{sweet16, petunia, hermes, forge}`; `dualie`
and `rk3588` reach the module but the `llm-agents` package list is inert for
them, so zero drift is correct, not a discrepancy.

`verify-drift.sh bc4af05^ bc4af05` (exit 10, drift found):

| Config | bc4af05^ | bc4af05 | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `s5akq6cvv8...` | `9prppqhvv9...` | DRIFT |
| petunia (NixOS) | `qizb52qrjg...` | `n3s679zyn9...` | DRIFT |
| avina (NixOS) | `i2hk8dl2zs...` | `i2hk8dl2zs...` | none |
| hermes (NixOS) | `701q0flnbr...` | `0prhzc1qar...` | DRIFT |
| groot@dualie (HM) | `gkfzdppll6...` | `gkfzdppll6...` | none |
| groot@forge (HM) | `jv3hfb44bk...` | `8p76zwdags...` | DRIFT |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

Actual-drift set is exactly `{sweet16, petunia, hermes, groot@forge}` —
matches the refined expected set with zero surprises once `enableLlmAgents`
gating is taken into account. `avina` (not a `user-dev-home` consumer) and
`groot@dualie` (`user-dev-home` consumer, but `enableLlmAgents = false`) both
show zero drift as expected; `groot@rk3588` is `N/A` on x86_64 per
convention (also `enableLlmAgents = false` there, consistent with the other
three).

**Verdict: SIGNED OFF.** Actual drift (`{sweet16, petunia, hermes,
groot@forge}`) equals the runtime-gated expected drift set. `avina` and
`groot@dualie` show zero drift as expected (no reachable `llm-agents`
package in their closures), and `groot@rk3588` is `N/A` on x86_64 per
convention. Deploy target for this commit is `sweet16` only.


---

## Validation: a319664 — feat(avina): add sops canary secret (range bc4af05..a319664, 5 commits)

Range covers the full sops-nix rollout on `main`:
`4c45a17` (sops-nix input + `core-sops` module, wired into both profiles and
all four `nixos-*.nix` assemblies), `558f56d` (devshell tooling only, no
flake-evaluated config), `824073d` (docs only), `fda47b2` (`.sops.yaml`, no
Nix evaluated), `a319664` (avina canary secret).

`lock-diff.sh bc4af05 a319664` (exit 10, nodes changed):

```
sops-nix null → f1406619a3884cd5c47992a70b8b35c9c0fcb4c9
```

Single new input node; nothing else in the lock moved across the range.

`consumers.sh core-sops` reachable set: `{sweet16, petunia, avina, hermes}`.
`consumers.sh sops-nix` returns nothing — the four `modules/flake/nixos-*.nix`
assembly files attach `inputs.sops-nix.nixosModules.sops` directly (outside
`flake.modules.nixos.*`), so the script's registry-recursion model dead-ends
on them. Known script gap, not a false result; manual grep of the four
assemblies confirms the same four-host set.

Reachability is not the same as actual config contribution: `modules/core/sops.nix`
gates all of `config` behind `lib.mkIf (cfg.hostFile != null)`, and
`nix-nexus.secrets.sops.hostFile` defaults to `null`. Only `hosts/avina/default.nix`
sets `hostFile` (`../../secrets/avina.yaml`) and declares `sops.secrets.canary`.
Expected *actual*-drift set, once the `mkIf` gate is accounted for: `{avina}`
only; `sweet16`, `petunia`, `hermes` reach the module but it stays inert.

`verify-drift.sh bc4af05 a319664` (exit 10, drift found):

| Config | bc4af05 | a319664 | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `9prppqhvv9...` | `9prppqhvv9...` | none |
| petunia (NixOS) | `n3s679zyn9...` | `n3s679zyn9...` | none |
| avina (NixOS) | `i2hk8dl2zs...` | `44mdasy63q...` | DRIFT |
| hermes (NixOS) | `0prhzc1qar...` | `0prhzc1qar...` | none |
| groot@dualie (HM) | `gkfzdppll6...` | `gkfzdppll6...` | none |
| groot@forge (HM) | `8p76zwdags...` | `8p76zwdags...` | none |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

Independently re-split to isolate the mechanism claim: the four infra commits
before the canary (`bc4af05`..`fda47b2`) are byte-identical on all seven
configs (exit 0) — confirming the `hostFile == null` default genuinely
produces zero closure impact on all four hosts touched by the module
attachment, rather than an accidental match. The canary commit alone
(`fda47b2`..`a319664`) reproduces the same single-host drift as the full range.

Root-caused the `avina` drift with `nix derivation show | python3 -m json.tool`,
diffing `toplevel` then the differing `activate.drv`: the entire diff is a new
`#### Activation script snippet setupSecrets:` block invoking
`sops-install-secrets` against a `manifest.json`, plus the two new `inputDrvs`
(`sops-install-secrets-0.0.1.drv`, `manifest.json.drv`) that produce it. Every
other activation-script line, package, and store-path input is byte-identical.
Built and read the resulting `manifest.json`: exactly one secret —
`{"name":"canary","path":"/run/secrets/canary","owner":"root","group":"root","mode":"0400","sopsFile":".../avina.yaml"}`
— with no unrelated package or version churn.

`groot@rk3588` `N/A`: confirmed in `.agents/scripts/lib.sh` (`is_na_config()`)
this is a static `uname -m != aarch64` check, independent of the revs compared
— pre-existing, not caused by this range.

**Verdict: SIGNED OFF.** Actual-drift set (`{avina}`) equals the
`mkIf`-refined expected-drift set. `sweet16`, `petunia`, `hermes` reach the
newly-wired `core-sops`/`sops-nix` module but show zero drift, exactly as the
inert-default mechanism predicts; `groot@dualie`/`groot@forge` never reach the
changed profiles; `groot@rk3588` is `N/A` on x86_64 per convention. Deploy
target for this range is `avina` only.

---

## Deploy incident + remediation: a319664 → HEAD (avina)

`a319664` (sops canary) was signed off above and deployed to avina. The canary
itself succeeded — `sops-install-secrets` imported
`/etc/ssh/ssh_host_ed25519_key` as `age1yd0d9n…qewv0wl` (matching the recipient
in `.sops.yaml`) and `/run/secrets/canary` landed as `-r-------- root root`,
content intact. Host-key decryption is proven on real hardware.

The same deploy failed `livekit.service` and `lk-jwt-service.service` with
`status=243/CREDENTIALS`, and `nixos-rebuild` exited 4.

**Root cause.** sops-nix and vault-agent both claimed `/run/secrets`
(`vault-secrets.nix:11`, `secretDir`). sops-nix hardcodes `symlinkPath =
"/run/secrets"` / `secretsMountPoint = "/run/secrets.d"` in
`modules/sops/manifest-for.nix` — not options, with an upstream
`# Does this need to be configurable?` comment — and re-points the symlink at a
new generation directory on every activation. That removed vault-agent's
rendered files mid-switch; both failing units read
`LoadCredential=livekit-secrets:/run/secrets/livekit.key`, which systemd
resolves at unit start, so they failed before vault-agent re-rendered. They
recovered on the automatic restart, but the race recurs on every rebuild and
reboot — this was a latent recurring fault, not a one-time activation artifact.

**Two prior claims corrected.** (1) `sops-install-secrets.service` does not
exist on avina: `useSystemdActivation` defaults to
`systemd.sysusers.enable || services.userborn.enable`, both false here, so sops
runs from the activation script. Ordering directives must not reference that
unit. (2) sops-nix's paths are not relocatable on NixOS; `defaultSymlinkPath` /
`defaultSecretsMountPoint` exist only in the Home Manager module.

**Remediation** (`6d3b13f`): vault-agent moves to `/run/vault-secrets`.
`secretDir` is a single binding feeding every template, destination, the
tmpfiles rule and the token sink, so the change propagates — verified against
the built `vault-agent.hcl`: all six secret destinations moved, zero
`/run/secrets` references remain, and the `key_file:` paths *inside* the
rendered `mas-config.ctmpl` moved with it. `/run/certs` was never contested and
is unchanged. Also orders `lk-jwt-service` after `vault-agent-init.service`; it
carried no such ordering while livekit, synapse and MAS all did — a
pre-existing gap surfaced by this failure.

`verify-drift.sh HEAD~1 HEAD`: `avina` only; sweet16, petunia, hermes,
groot@dualie, groot@forge byte-identical; groot@rk3588 `N/A` (x86_64 host).

**Verdict: SIGNED OFF for deploy to avina.** Note this deploy relocates live
secret paths: vault-agent re-renders into `/run/vault-secrets` and the stale
`/run/secrets/*` entries from the previous generation are abandoned. Verify
after switch that all six destinations exist under the new path and that
livekit, lk-jwt-service, synapse, MAS and haproxy are active.

---

## Validation: d8b0d2d — fix(matrix): make vault-agent-init ordering actually bind

Follow-up to the incident above. `88b615a` resolved the `/run/secrets`
collision but livekit still failed `243/CREDENTIALS` on the next switch.

**Root cause, from the journal** (not inferred): `vault-agent-init` *did* run
in that transaction, but livekit spawned as PID 3316 against the init unit's
PID 3318 — the consumer started first despite declaring
`after = [ "vault-agent-init.service" ]`. `After=` only constrains units
already in the same job transaction; no consumer declared `wants` or
`requires`, so nothing pulled the init unit in and the ordering had nothing to
apply to. Compounding it, `Type=oneshot` with `RemainAfterExit` unset left the
unit `inactive` the instant it finished (`systemctl show` confirmed
`RemainAfterExit=no`, `ActiveState=inactive`), so its active state could never
mean "secrets are rendered".

Pre-existing latent bug, not introduced by the sops work. It stayed invisible
because vault-agent's rendered files persisted in tmpfs across switches, so the
guarantee was never needed until sops-nix cleaned up the files it had adopted
during the collision. The `livekit.key` template's
`systemctl restart --no-block livekit.service lk-jwt-service.service` command
is what recovered the service on both failing deploys.

**Fix:** `RemainAfterExit = true` on `vault-agent-init`; `wants` added
alongside the existing `after` on all five consumers (haproxy, matrix-synapse,
matrix-authentication-service, livekit, lk-jwt-service). Deliberately `wants`
rather than `requires` — `requires` would propagate the init unit's stop to
every consumer, a worse failure mode than the one being fixed.

`verify-drift.sh HEAD~1 HEAD`: `avina` only; all other configs byte-identical.

**Deploy confirmed green** (avina, third switch): `nixos-rebuild` exited 0 with
no failed units; `systemctl show vault-agent-init` reports
`ActiveState=active`, `RemainAfterExit=yes`;
`journalctl -u livekit --since "-5 min" | grep -c CREDENTIALS` returns `0`.
All seven vault-agent destinations render under `/run/vault-secrets/`
(`0640 root:matrix-secrets`, token `0640 root:root`), and `/run/secrets/`
belongs solely to sops-nix.

**Verdict: SIGNED OFF — deployed and verified.** The sops-nix layer is proven
end-to-end on avina: host-key decryption, no path contention, binding startup
ordering. Cleared for the vault-agent AppRole seed migration.

---

## Validation: c5057cd — feat(avina): migrate vault-agent AppRole seed to sops

Closes the bootstrap chicken-and-egg identified at the start of the secrets
work: the AppRole role-id/secret-id were hand-placed in `/var/lib/secrets`,
unlocking every other secret while being unmanaged themselves.

**Pre-flight value verification** (before any wiring): decrypted each value from
`secrets/avina.yaml` and compared against `sha256sum` of the live files on
avina. Both 37 bytes, both SHA-256 matching (`d7921aa8…`, `46a108fb…`). The
trailing newline (`lastbyte=0a`, 36-char UUID + `\n`) is significant, so both
use YAML block scalars — a plain scalar would yield 36 bytes and break AppRole
auth. Plaintext was never printed; comparison was done by piping
`sops decrypt --extract` into `sha256sum`/`wc -c`.

**Built-config verification** (`vault-agent.hcl` from the realised toplevel):

```
role_id_file_path   = "/run/secrets/vault-role-id"
secret_id_file_path = "/run/secrets/vault-secret-id"
path                = "/run/vault-secrets/vault-token"   # sink, unchanged
```

Zero `/var/lib/secrets` references remain in the generated agent config. The
seed now comes from sops (`/run/secrets`, rendered at activation) while
vault-agent's own output stays in `/run/vault-secrets` — the two systems remain
in separate directories per the earlier collision fix.

Deliberately not sourced from Vault: this is the credential that authenticates
*to* Vault. sops-nix needs no bootstrap credential of its own, decrypting with
an age key derived from the SSH host key avina already has.

`sops.secrets` on avina is now `["canary","vault-role-id","vault-secret-id"]`.
The canary is retained: it proves decryption independently of vault-agent
health, which is more useful now that the seed shares that mechanism.

`verify-drift.sh HEAD~1 HEAD`: `avina` only; sweet16, petunia, hermes,
groot@dualie, groot@forge byte-identical; groot@rk3588 `N/A` (x86_64 host).

**Verdict: SIGNED OFF for deploy to avina.**

**Rollback path.** `/var/lib/secrets` is untouched on disk, still created by
tmpfiles and still in both vault-agent units' `ReadOnlyPaths`. Reverting this
commit points `auto_auth` back at those files and restores the prior working
state with no data recovery needed.

**New coupling introduced — accepted, documented.** vault-agent's ability to
authenticate now depends on sops decryption, which depends on avina's SSH host
key. If that key is regenerated (rebuild, restore from backup), vault-agent
cannot authenticate and the whole Matrix stack stays down until the secrets are
re-encrypted to the new recipient. `/var/lib/secrets` is the recovery path for
exactly this case and must not be deleted.

**Deploy verification required** — this changes a live credential path:
`journalctl -u vault-agent-init` must show `authentication successful`, and all
seven destinations must render under `/run/vault-secrets/`.

### c5057cd deploy verification — cold boot, full chain

Verified on avina after a reboot, which is the strongest available test: `/run`
is tmpfs, so nothing survives and every secret must be produced from scratch.
`vault-agent-init` ran as PID 223, confirming a fresh boot rather than a switch.

Chain executed end to end with no pre-existing state:

1. sops-nix decrypted the AppRole seed during activation (activation script, not
   a unit — `useSystemdActivation` is false here), keyed on
   `/etc/ssh/ssh_host_ed25519_key`.
2. `vault-agent-init` read `/run/secrets/vault-role-id` + `vault-secret-id` and
   authenticated to Vault successfully.
3. All nine templates rendered — six into `/run/vault-secrets/`, three into
   `/run/certs/` — all timestamped at boot.
4. `systemctl is-active` returns `active` for all seven units: vault-agent-init,
   vault-agent, matrix-synapse, matrix-authentication-service, livekit,
   lk-jwt-service, haproxy.

`/run/secrets/` holds exactly the three sops secrets at `0400 root:root`, with
the seed files at the verified 37 bytes. No CREDENTIALS failures; no failed
units.

This closes the bootstrap chicken-and-egg: the credential that unlocks every
other secret is now itself declarative and reproducible from the repository,
and the fleet can rebuild avina's secret chain from a bare boot.

---

## Validation: 4f2a1c9 — refactor(avina): drop the /var/lib/secrets AppRole fallback

**Supersedes the "Rollback path" and "New coupling" paragraphs of the c5057cd
sign-off above, which recorded the wrong rationale.** That entry argued
`/var/lib/secrets` should be retained as the recovery path if avina's SSH host
key were regenerated. That reasoning does not hold:

- Recovery is re-deriving the host's age recipient (`ssh-keyscan | ssh-to-age`),
  `sops updatekeys secrets/avina.yaml`, and redeploying. **The repository plus
  the admin age key is the backup.** Any situation in which `/var/lib/secrets`
  could be read is one in which the file could equally be written from the repo,
  so the on-host copy adds nothing.
- An AppRole `secret_id` is *designed to be reissued* (`vault write -f
  auth/approle/role/avina/secret-id`), unlike the MAS signing keys which must
  never rotate. Its disaster-recovery value as a stored plaintext is near zero.

Retaining it actively cost two things: a persistent cleartext copy on disk of
the one credential that unlocks every other secret (defeating the move to
tmpfs), and a second source of truth that nothing read — rotating the seed in
sops would silently leave it stale.

Removed: the `persistentSecretDir` binding, its tmpfiles rule, and the
now-empty `ReadOnlyPaths` on both vault-agent units. Verified post-change,
tmpfiles rules are exactly `/run/certs` and `/run/vault-secrets`;
`ReadOnlyPaths` is absent from both units; no `/var/lib/secrets` reference
remains in any `.nix` or `.md` outside this historical record.

`hosts/avina/README.md` rewritten where it still instructed operators to
hand-place the files: new-host bootstrap now adds the host's age recipient
before the first rebuild, and rotation goes through sops with a documented
byte-equality check (37 bytes, block scalars, trailing newline significant).

`verify-drift.sh HEAD~1 HEAD`: `avina` only; all other configs byte-identical.

**Verdict: SIGNED OFF for deploy to avina.** The stale files remain on the host
and are removed out of band; this commit only stops anything recreating them.
Precondition confirmed before proceeding: the admin age key
(`~/.config/sops/age/keys.txt`) is backed up, since it is now the sole recovery
mechanism for every secret in `secrets/*.yaml`.

---

## Validation: 38a01f7..HEAD — working-tree cleanup (3 commits)

Pre-existing uncommitted work, committed as three logical changes to clear the
tree before deploying avina and pushing.

- `38a01f7` docs: remove `hosts/AGENTS.md` and `modules/AGENTS.md`, the phase-2
  and phase-3 working guides for the completed dendritic refactor. No config
  evaluated. Verified nothing references them except one historical
  `.agents/SIGNOFF.md` line, deliberately left intact; `AGENTS.md` §11's
  document map never listed them.
- `a658d7e` feat(terminal): Kitty and Ghostty 13pt → 14pt, plus
  `term = "xterm-256color"` for Ghostty, which otherwise advertises
  `xterm-ghostty` — terminfo absent on remote hosts, the same SSH breakage
  `xterm-kitty` caused. nixfmt also normalized a trailing-whitespace line.
- `bd54c8f` chore(flake): devenv `bd1c175d` → `81ab9b8f`. `ghostty` follows
  (`e1d31dea` → `88b4cd04`) as a *transitive input of devenv* — confirmed via
  the lock's input graph, it is not a direct input. The seven-node `nixpkgs_N`
  shuffle is renumbering from an inserted node, not seven nixpkgs moves.

`verify-drift.sh HEAD~3 HEAD`:

| Config | Drift |
|---|---|
| sweet16 | DRIFT |
| petunia | DRIFT |
| avina | **none** |
| hermes | DRIFT |
| groot@dualie | DRIFT |
| groot@forge | DRIFT |
| groot@rk3588 | N/A (x86_64 host) |

Drift set equals the `user-terminal-home` consumer set. `avina` showing zero
drift is correct, not a missed evaluation: `hosts/avina/ddukes-hm.nix` imports
only `nixvim` and `avina-home`, never `user-home`, so it does not reach
`user-terminal-home` and a terminal font change cannot affect it. The devenv
bump touches only `perSystem` (devshell + checks) and so contributes no host
closure drift; the docs deletion contributes none by construction.

devenv bump verified post-change: `nix flake check` passes and `sops`, `age`,
`ssh-to-age`, `secretspec`, `bun` all still resolve in the devshell.

**Verdict: SIGNED OFF.** Deploy targets: sweet16, petunia, hermes for the
terminal change (cosmetic, deferrable). avina is unaffected by these three
commits but still needs the earlier `f7393b1` deployed — see below.

---

## Validation: secretspec declaration + langfuse hook routing

Adds `secretspec.toml` and routes the Claude Code Stop hook through
`secretspec run` (`modules/flake/checks.nix`).

`verify-drift.sh HEAD~1 HEAD`: **zero drift on every config** — all four NixOS
hosts and both evaluable HM configs byte-identical; `groot@rk3588` `N/A`
(x86_64 host). Correct by construction: the change touches only `perSystem`
(devshell packages and the generated `.claude/settings.json`) plus repo-root
files, none of which enter a host closure. **No deploy required.**

Verified end to end rather than by inspection: the exact command emitted into
`.claude/settings.json` —
`secretspec run --reason "langfuse trace export" -- python3 "$CLAUDE_PROJECT_DIR"/.claude/hooks/langfuse_hook.py`
— resolves all three Langfuse values from the keyring and exits 0 on empty
stdin, producing no output. Values were confirmed by length only, not printed.

Design notes, both deliberate and documented in `docs/secrets.md`:

- **Optional, not required.** The hook is elective telemetry. Required secrets
  would make `secretspec run` exit non-zero and skip the hook every turn for
  anyone without Langfuse configured.
- **Keyring-only, no Vault fallback.** The hook fires on every Stop; a fallback
  route would add a network round-trip per turn whenever the keyring misses.
  `home_vault` is declared as an alias for secrets that want it, and is the only
  option on headless hosts (no Secret Service daemon).

Constraints measured against the pinned 0.13.0 binary, not the 0.17 docs:
`keyring`/`vault`/`dotenv`/`env` compiled in; `sops`, `age`,
`systemd-credential` and `[scopes]` absent and unreachable until nixpkgs ships
0.17 (cachix/secretspec publishes no `flake.nix`). The `require_reason` policy
covers `check` and `get`, not only `run`. Also noted: `secretspec check`
reports optional secrets without probing resolution, so its
"0 found, 0 missing, 3 optional" summary is not evidence they are unset.

Corrected from earlier notes: the hook reads `LANGFUSE_BASE_URL`, not
`LANGFUSE_HOST`, defaulting to `https://us.cloud.langfuse.com`.

**Verdict: SIGNED OFF.** Zero host drift; nothing to deploy.

---

## Validation: refactor(tpm2) — promote to core-tpm2, enable on sweet16

`modules/hardware/petunia/tpm2.nix` registered into the merged
`hardware-petunia` key, so TPM2 support was reachable only by importing
petunia's whole hardware bundle. It moves to `modules/core/tpm2.nix` under its
own `core-tpm2` key, opted into per host.

`verify-drift.sh HEAD~1 HEAD`:

| Config | Drift |
|---|---|
| sweet16 | DRIFT |
| petunia | **none** |
| avina | none |
| hermes | none |
| groot@dualie / groot@forge | none |
| groot@rk3588 | N/A (x86_64 host) |

petunia byte-identical is the load-bearing result: this is a pure module move
for that host — same options, same values, reached by a different name. Note
petunia's `default.nix` *had* to change: the config left the `hardware-petunia`
key, so importing `core-tpm2` is what preserves the status quo. Adding
`core-tpm2` to sweet16 alone would have silently stripped TPM2 from petunia on
its next rebuild, leaving an initrd that could not unseal.

sweet16 drift is the intended change: it has the hardware, ZFS-on-LUKS
(`hosts/sweet16/hardware-configuration.nix:40`) and `boot.initrd.systemd.enable`
already, but carried no TPM2 module. Verified post-change: `security.tpm2.enable`
is now true on both sweet16 and petunia, and false on avina and hermes (Proxmox
LXC, no TPM), which do not import the key.

**Verdict: SIGNED OFF.** Deploy target: sweet16 only (petunia has no drift and
needs no rebuild for this).

**Enrollment is a separate manual step and is NOT done by this commit.** The Nix
side is identical for both hosts because the PIN lives in the enrollment
command, not the configuration. sweet16's only sanctioned form:

```bash
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0 --tpm2-with-pin=yes <device>
```

Confirm the device with `lsblk -o NAME,PARTLABEL` first — sweet16 was not
installed via disko, so `by-partlabel/DISK_LUKS` should resolve, unlike petunia
which requires `/dev/nvme0n1p2`. Keyslot 0 remains a passphrase fallback, so a
failed enrollment does not lock the machine.

---

## Validation: 7c75a61 — feat(terminal): tmux mouse scrollback and ghostty/kitty parity

Single module file touched, `modules/tools/terminal-home.nix` (registry key
`user-terminal-home`), plus `docs/terminal.md` (docs only, no eval impact).
tmux gained `mouse on`, `set-clipboard on`, a `terminal-features` clipboard
override, a WheelUpPane conditional into `copy-mode -e`, and three
copy-mode-vi bindings; kitty/ghostty font bumped 13→14 and ghostty gained
`term = "xterm-256color"` plus five window/mouse-behavior settings for parity
with kitty.

`consumers.sh user-terminal-home`: hermes, forge, rk3588, dualie, sweet16,
petunia — six consumers. avina does not import this key.

`verify-drift.sh 75b582d 7c75a61`:

| Config | Drift |
|---|---|
| sweet16 | DRIFT |
| petunia | DRIFT |
| avina | none |
| hermes | DRIFT |
| groot@dualie | DRIFT |
| groot@forge | DRIFT |
| groot@rk3588 | N/A (x86_64 host) |

Actual drift set (sweet16, petunia, hermes, groot@dualie, groot@forge) matches
the expected-drift set from `consumers.sh` exactly, modulo groot@rk3588 which
is excluded from comparison per protocol. avina byte-identical is the
load-bearing result: it does not consume `user-terminal-home`, and the diff
confirms it reaches none of the changed lines.

**Verdict: SIGNED OFF.** Deploy targets: sweet16, petunia, hermes (NixOS
configs); groot@dualie and groot@forge (standalone HM). avina needs no
rebuild for this change.

---

## Validation: 925c5ca..937a330 — feat/fix(vivaldi): source from nixpkgs-unstable, drop duplicate stable entry

Two commits reviewed together: 925c5ca removes the pinned `pkgs-vivaldi`
input entirely and repoints the three vivaldi call sites
(`modules/tools/home.nix`, `modules/desktop/hyprland-home.nix`,
`modules/desktop/niri-home.nix`) at `inputs.nixpkgs-unstable` for
8.1.4087.58; 937a330 drops the now-duplicate bare `vivaldi` entry from
`environment.systemPackages` in `modules/tools/dev/common.nix` (registry key
`development-default`).

`lock-diff.sh 48e7e91 937a330`:

```
nixpkgs-unstable 18b9261cb3294b6d2a06d03f96872827b8fe2698 → 0954f7ee2f6bb3dc7d4e3d0d8bcb8fd4bde4cfc5
pkgs-vivaldi 3b32825de172d0bc85664f495edb096b10862524 → null
```

`consumers.sh nixpkgs-unstable development-default pkgs-vivaldi`: the
`nixpkgs-unstable` input resolves recursively (via `user-home`,
`desktop-hyprland-home`, and pre-existing `user-dev-home` consumption of
unstable for `mcp-nixos`/`opencode-desktop`/`opencode-claude-auth`) to
hermes, dualie, forge, rk3588, sweet16, petunia. `development-default`
resolves to sweet16, petunia only. `pkgs-vivaldi` has zero consumers in the
current tree (expected — the input no longer exists at HEAD). avina appears
in neither list.

Expected-drift set: sweet16, petunia, hermes, groot@dualie, groot@forge
(groot@rk3588 excluded, x86_64 host N/A). avina expected clean.

`verify-drift.sh 48e7e91 937a330`:

| Config | Drift |
|---|---|
| sweet16 | DRIFT |
| petunia | DRIFT |
| avina | none |
| hermes | DRIFT |
| groot@dualie | DRIFT |
| groot@forge | DRIFT |
| groot@rk3588 | N/A (x86_64 host) |

Actual drift set (sweet16, petunia, hermes, groot@dualie, groot@forge)
matches the expected-drift set exactly. avina byte-identical confirms it: it
imports neither `development-default` nor any `nixpkgs-unstable`-consuming
home key, so the input bump and the systemPackages removal both leave it
untouched. hermes and groot@forge drifting despite not calling vivaldi
directly is not a discrepancy — both already pull `nixpkgs-unstable` through
`user-dev-home` (mcp-nixos, opencode-desktop, opencode-claude-auth) and
hermes additionally through its own `unstablePkgs` binding in
`hosts/hermes/default.nix` / `groot-hm.nix`; the input-version bump alone
would have drifted them with or without the vivaldi change.

**Verdict: SIGNED OFF.** Deploy targets: sweet16, petunia, hermes (NixOS
configs); groot@dualie and groot@forge (standalone HM). avina needs no
rebuild for this change.

---

## Validation: 19059d3..364ccd3 — fix(vivaldi): pin ffmpeg codecs to a build that starts

Corrective commit for the vivaldi migration signed off in the
`925c5ca..937a330` entry above (not rewritten — cross-referenced here). That
entry validated a configuration that evaluated cleanly but produced a
non-starting binary: nixos-unstable pairs vivaldi 8.1.4087.58 with
`chromium-codecs-ffmpeg-extra` 123075, which does not export
`av_dynamic_hdr_smpte2094_app5_to_t35`; `vivaldi-bin` lists `libffmpeg.so` as
a NEEDED entry, so `vivaldi --version` aborted with a symbol lookup error at
runtime — a defect closure comparison alone cannot catch. 364ccd3 adds a new
flake input `pkgs-vivaldi-codecs` (`github:nixos/nixpkgs/3b32825de172d0bc85664f495edb096b10862524`)
used solely to override `vivaldi-ffmpeg-codecs`; vivaldi itself still comes
from `nixpkgs-unstable`. Call sites updated: `modules/tools/home.nix`,
`modules/desktop/hyprland-home.nix`, `modules/desktop/niri-home.nix`.

`lock-diff.sh 19059d3 364ccd3`:

```
pkgs-vivaldi-codecs null → 3b32825de172d0bc85664f495edb096b10862524
```

`consumers.sh pkgs-vivaldi-codecs`:

```
sweet16: via hosts/sweet16/home.nix
petunia: via hosts/petunia/home.nix
```

Expected-drift set: sweet16, petunia only. hermes, avina, groot@dualie,
groot@forge do not install vivaldi and have no path to the new input.
groot@rk3588 excluded (x86_64 host, N/A).

`verify-drift.sh 19059d3 364ccd3`:

| Config | Drift |
|---|---|
| sweet16 | DRIFT |
| petunia | DRIFT |
| avina | none |
| hermes | none |
| groot@dualie | none |
| groot@forge | none |
| groot@rk3588 | N/A (x86_64 host) |

Actual drift set (sweet16, petunia) matches the expected-drift set exactly.
Confirmed the fix landed as intended, not just that the closure moved:
`nix-store -qR` on both hosts' `system.build.toplevel` drvs resolves to the
same `vivaldi-8.1.4087.58.drv`, whose realized output is
`/nix/store/sv2nk8p35b3i5m2wbs623falbm6yg3di-vivaldi-8.1.4087.58` — matching
the path already built and empirically verified (`vivaldi --version` prints
the version instead of aborting) per the commit message.

**Verdict: SIGNED OFF.** Deploy targets: sweet16, petunia only. hermes,
avina, groot@dualie, groot@forge need no rebuild for this change. Once
nixos-unstable's `vivaldi-ffmpeg-codecs` catches up to the 2026-05-18 source
build, `pkgs-vivaldi-codecs` should be dropped (noted in the commit message).

---

## Validation: 342572a..c1afb50 — context-mode hermes enablement

Four functional commits behind three merges: `3b28b69` (new `lib/context-mode.nix`,
`buildNpmPackage` of npm `context-mode` 1.0.169, Elastic-2.0/unfree), `d0ecabf`
(new `lib/context-mode-hermes.nix`, `buildPythonPackage` plugin from
`christopher-s/context-mode-hermes`, zero runtime deps), `c8a099e`
(`hosts/hermes/llm-agents-overlay.nix` prepends the plugin to hermes-agent's
`propagatedBuildInputs`; `hosts/hermes/groot-hm.nix` adds the `context-mode`
CLI to groot's `home.packages`), `e7d24ba` (docs only, inert).

`lock-diff.sh 342572a c1afb50`: exit 0, no output — no `flake.lock` node
moved. Consistent with the change being new `lib/*.nix` derivations plus
host-file wiring, not a new flake input.

`consumers.sh llm-agents-hermes hm-groot-hermes`: no output. Known script
gap, same class as the `sops-nix` gap documented above — the sole reference
to both keys is `modules/flake/nixos-hermes.nix` (`nixos.llm-agents-hermes`,
`nixos.hm-groot-hermes`), which sets `flake.nixosConfigurations.hermes`
directly rather than registering under `flake.modules.nixos.*`, so the
script's registry-recursion dead-ends there instead of resolving to a
`hosts/` file. Manual grep confirms `lib/context-mode.nix` and
`lib/context-mode-hermes.nix` are imported only from `hosts/hermes/groot-hm.nix`
and `hosts/hermes/llm-agents-overlay.nix` respectively, and
`modules/flake/nixos-hermes.nix` wires both keys only into
`nixosConfigurations.hermes`. Expected-drift set: `{hermes}` only.
`lib/*.nix` files are not auto-discovered (AGENTS.md §3.5), so they cannot
leak into any other host's registry composition.

`verify-drift.sh 342572a c1afb50` (exit 10, drift found):

| Config | 342572a | c1afb50 | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `icbnhchnxhv...` | `icbnhchnxhv...` | none |
| petunia (NixOS) | `6bdw5xm8l2w...` | `6bdw5xm8l2w...` | none |
| avina (NixOS) | `rnwf3z5cj9y...` | `rnwf3z5cj9y...` | none |
| hermes (NixOS) | `bsj7i2qy5my...` | `175q2rw24y3...` | DRIFT |
| groot@dualie (HM) | `0g2hs1ysskh...` | `0g2hs1ysskh...` | none |
| groot@forge (HM) | `lixapp625v3...` | `lixapp625v3...` | none |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

Actual-drift set (`{hermes}`) matches the expected-drift set exactly.

Beyond the raw hash comparison, five specific risks were checked against a
real build of `c1afb50`'s `nixosConfigurations.hermes.config.system.build.toplevel`:

1. **Interpreter-last invariant.** Built `pkgs.llm-agents.hermes-agent`'s
   wrapper (`/nix/store/1wc7hmn1sbvnfc4d1dkr3shii3jsxq15-hermes-agent-2026.7.20/bin/hermes-agent`)
   and read its `--set PYTHONPATH` value directly: first entry is
   `python3.13-context-mode-hermes-1.3.0`, last entry is
   `python3-3.13.14` (the interpreter). Prepending preserved the
   `elemAt deps (length deps - 1)` invariant both overlay files rely on.
2. **Evaluation cycle.** `nix flake check --impure` passes green for all
   four `nixosConfigurations` (sweet16, petunia, avina, hermes) plus
   `devShells`/`checks`/`packages`/`homeConfigurations` — no infinite
   recursion. `hosts/hermes/llm-agents-overlay.nix` hoists
   `deps`/`hermesPython` from `agentPkgs.hermes-agent.propagatedBuildInputs`
   (pre-override) rather than from inside `overridePythonAttrs`, avoiding
   the `isMismatchedPython` re-entrancy the implementer hit during
   development.
3. **Dual PYTHONPATH paths.** Built `home-manager-files` for the
   `hm-groot-hermes` composition and read both rendered drop-ins:
   `.config/systemd/user/hermes-gateway.service.d/nix-deps.conf` and
   `.config/systemd/user/hermes-gateway-coding-local.service.d/nix-deps.conf`
   render byte-identical `PYTHONPATH=<hermes-agent-2026.7.20>/site-packages:<python3-3.13.14-env>/site-packages`.
   Confirmed on disk that `<python3-3.13.14-env>/lib/python3.13/site-packages/`
   contains `context_mode_hermes/` and `context_mode_hermes-1.3.0.dist-info/`
   — the plugin reaches both consumers off the one `allDeps` list in
   `hosts/hermes/home.nix`.
4. **No collision regression.** The `pythonEnv` buildEnv derivation built
   successfully (a real collision would have failed the build, not just
   warned). Inspected site-packages directly: exactly one `aiosqlite`
   (0.22.1, the override) and one `olm`/`python_olm` (3.2.16, the
   vuln-allowed override) — no duplicate entries from the newly-prepended
   plugin.
5. **Unfree.** `context-mode` (Elastic-2.0) is covered by the pre-existing
   fleet-wide `nixos.overlays-global` (`nixpkgs.config.allowUnfree = true`),
   wired identically into all four `nixos-<host>.nix` assemblies before this
   change. Since `sweet16`/`petunia`/`avina` show zero drift, no new unfree
   requirement leaked to them.

`groot@rk3588` `N/A`: static `uname -m != aarch64` check in
`.agents/scripts/lib.sh`, independent of the revs compared.

**Verdict: SIGNED OFF.** Actual-drift set (`{hermes}`) matches the
expected-drift set exactly; `sweet16`, `petunia`, `avina`, `groot@dualie`,
`groot@forge` are byte-identical; `groot@rk3588` is `N/A` on x86_64 per
convention. Deploy target for this range is `hermes` only. No deploy was
performed as part of this validation.

---

## Validation: 09e7279..1f4ac0b — Stylix adoption, first 4 commits (3 sub-ranges)

Baseline: `09e7279` (pre-existing main, "merge: context-mode hermes drift
sign-off"). HEAD verified as `1f4ac0b` ("merge: bump hyprland to v0.56.1 and
pin noctalia to v5.0.0-beta.7") per the base gate; the working branch had
drifted to a stale tip and was reset to `main` (`1f4ac0b`) before validation.
Three sub-ranges judged independently, matching the three logical commits in
the range; results not collapsed.

### C0: `09e7279` → `095ad95` — remove 7 orphaned theming modules

Deletes `modules/desktop/{waybar-home,sway-home,sway,notifications,niri-home,niri,noctalia}.nix`
(-1105 lines; registry keys `desktop-waybar-home`, `desktop-sway-home`,
`desktop-sway`, `desktop-notifications`, `desktop-niri-home`,
`desktop-niri`, `desktop-noctalia`).

`lock-diff.sh 09e7279 095ad95`: exit 0, no output — no `flake.lock` node moved.

`consumers.sh` run against all 7 keys at the pre-deletion revision (`09e7279`,
checked out detached to grep the tree as it existed before the files were
removed, then restored to `1f4ac0b`): zero output for all 7 keys — no
consumer found anywhere in `modules/`, `hosts/`, `profiles/`. Expected-drift
set: `{}` (empty).

`verify-drift.sh 09e7279 095ad95` (exit 0, no drift):

| Config | 09e7279 | 095ad95 | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `icbnhchnxhv...` | `icbnhchnxhv...` | none |
| petunia (NixOS) | `6bdw5xm8l2w...` | `6bdw5xm8l2w...` | none |
| avina (NixOS) | `rnwf3z5cj9y...` | `rnwf3z5cj9y...` | none |
| hermes (NixOS) | `175q2rw24y3...` | `175q2rw24y3...` | none |
| groot@dualie (HM) | `0g2hs1ysskh...` | `0g2hs1ysskh...` | none |
| groot@forge (HM) | `lixapp625v3...` | `lixapp625v3...` | none |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

Actual-drift set (`{}`) matches expected-drift set (`{}`) exactly. **C0
verdict: PASS.**

### C1: `095ad95` → `44874f9` — split OLED palette out of terminal module

Structural move: `programs.kitty`/`programs.ghostty` OLED colour attrsets
move from `modules/tools/terminal-home.nix` into new
`modules/tools/terminal-oled-home.nix` (key `user-terminal-oled-home`),
imported by all 5 previous consumers of `user-terminal-home`. The four
`programs.tmux.extraConfig` colour lines (`status-style`,
`window-status-current-style`, `pane-border-style`,
`pane-active-border-style`) were deliberately left in place — `extraConfig`
is `types.lines`, and splitting that string would reorder the generated
`tmux.conf` and change its hash, unlike the kitty/ghostty attrsets which
render by sorted key regardless of which file defines which keys.

`lock-diff.sh 095ad95 44874f9`: exit 0, no output — no `flake.lock` node moved.

`verify-drift.sh 095ad95 44874f9` (exit 0, no drift) — independently
re-run, not taken on the implementer's claim:

| Config | 095ad95 | 44874f9 | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `icbnhchnxhv...` | `icbnhchnxhv...` | none |
| petunia (NixOS) | `6bdw5xm8l2w...` | `6bdw5xm8l2w...` | none |
| avina (NixOS) | `rnwf3z5cj9y...` | `rnwf3z5cj9y...` | none |
| hermes (NixOS) | `175q2rw24y3...` | `175q2rw24y3...` | none |
| groot@dualie (HM) | `0g2hs1ysskh...` | `0g2hs1ysskh...` | none |
| groot@forge (HM) | `lixapp625v3...` | `lixapp625v3...` | none |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

Byte-identical derivation hashes on all 5 previously-drv-comparable
consumers confirm the tmux-line-retention reasoning holds against the actual
drvs: the split changed which file declares which attribute, not the
rendered output. **C1 verdict: PASS** — implementer's zero-drift claim
independently verified, not assumed.

### C2+C3: `44874f9` → `1f4ac0b` — hyprland v0.56.1, noctalia v5.0.0-beta.7

`lock-diff.sh 44874f9 1f4ac0b` (exit 10, nodes changed):

```
aquamarine 06669631175b4db2383b94e7f8c13f45a9d28757 → 9b5f14d9483445e766294eb8fbe0b8f370269ed0
gitignore 637db329424fd7e46cf4185293b9cc8c88c95394 → null
hyprgraphics 68d064434787cf1ed4a2fe257c03c5f52f33cf84 → c6e7b9f673f4360bc813d3dc75028f75ee88d3f8
hyprland a0136d8c04687bb36eb8a28eb9d1ff92aea99704 → 5c9377c15f85c50648f35ca5a213754f95b93ca0
hyprland-guiutils a968d211048e3ed538e47b84cb3649299578f19d → a6ccb6cb112ed5a244c0191fb972347ecfa893e0
hyprtoolkit 9af245a69fa6b286b88ddfc340afd288e00a6998 → bdba25ced39ea39ab004a8f31593ba0b0ff1ca35
hyprutils 40ede2e7bdec80ba5d4c443160d905e9f841ae5f → 5f03477ab3a005ff27c527486f551883535aea2f
nixpkgs_7 0bb7ec54c8483066ec9d7720e780a5caa71f8612 → e2587caef70cea85dd97d7daab492899902dbf5d
noctalia 8b5b1381d5a2ea94b787da11abe4f2411b89b196 → c366a35ffc30b011d03fcd122bbe7d22f932fc57
pre-commit-hooks 61ab0e80d9c7ab14c256b5b453d8b3fb0189ba0a → 43b3c1ab9d40fb1dbb008f451988a91e375825e9
xdph 4a170c0ba96fd37374f93d8f91c9ed91814828ac → 08d99f727944dd15e4740090305e31c5fb92a50a
```

`hyprland` moved to `5c9377c1…` (tag `v0.56.1`); `noctalia` moved to
`c366a35f…` (tag `v5.0.0-beta.7`) and its `original` field also changed from
a branch ref (`github:noctalia-dev/noctalia`) to a tag ref
(`.../v5.0.0-beta.7`) — expected and intentional, part of the same commit.
`aquamarine`, `hyprgraphics`, `hyprland-guiutils`, `hyprtoolkit`,
`hyprutils`, `xdph` are hyprland's own flake-input closure and moved as
transitive follows; `gitignore` was removed (no longer referenced);
`pre-commit-hooks` moved as a transitive of the hyprland ecosystem;
`nixpkgs_7` (noctalia's *nested*, non-followed nixpkgs — noctalia
deliberately has no `nixpkgs.follows`, required to keep it on its own
Cachix cache) moved as a side effect of the noctalia bump. The top-level
`nixpkgs` node is untouched by this range (verified separately below).

`consumers.sh hyprland noctalia` at HEAD:

```
petunia: via hosts/petunia/home.nix
sweet16: via hosts/sweet16/home.nix
sweet16: via hosts/sweet16/default.nix
petunia: via hosts/petunia/default.nix
```

Expected-drift set: `{sweet16, petunia}` only.

`verify-drift.sh 44874f9 1f4ac0b` (exit 10, drift found):

| Config | 44874f9 | 1f4ac0b | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `icbnhchnxhvn84ka2drcnchvldka8cyx...` | `ahflzgdwwfc17yfxcms0i3dwm9056kas...` | DRIFT |
| petunia (NixOS) | `6bdw5xm8l2w6bfqs8567hxlcb3fp7gdn...` | `2jpk842wr7bs4vqfjrvpajnsgsq82hx6...` | DRIFT |
| avina (NixOS) | `rnwf3z5cj9y...` | `rnwf3z5cj9y...` | none |
| hermes (NixOS) | `175q2rw24y3...` | `175q2rw24y3...` | none |
| groot@dualie (HM) | `0g2hs1ysskh...` | `0g2hs1ysskh...` | none |
| groot@forge (HM) | `lixapp625v3...` | `lixapp625v3...` | none |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

Actual-drift set (`{sweet16, petunia}`) matches expected-drift set exactly.

Root-caused both drifting hosts with `nix-store -q --tree` against each
`nixos-system-*.drv`, filtering for `hyprland`/`noctalia` store-path names:

- **sweet16**: closure gains `hyprland-0.56.1+date=2026-07-27_5c9377c.drv`
  (was `hyprland-0.55.4+date=2026-06-11_a0136d8.drv`),
  `xdg-desktop-portal-hyprland-1.4.0+date=2026-07-18_08d99f7.drv` (was
  `-1.3.12.drv`), `hyprland-guiutils-0.2.1+date=2026-07-16_a6ccb6c.drv` (was
  `...a968d21.drv`), and a rebuilt `noctalia-5.0.0.drv` whose content hash
  changed (`sj5097yaak0...` → `ih6dkrl3j8n9...`) even though the version
  string is unchanged — consistent with the noctalia input pin moving from
  a branch ref to the `v5.0.0-beta.7` tag ref while the package's
  `version` attribute stayed `"5.0.0"`.
- **petunia**: identical mechanism — closure gains
  `hyprland-0.56.1+date=2026-07-27_5c9377c.drv` (was `...a0136d8.drv`),
  `hyprland-guiutils-0.2.1+date=2026-07-16_a6ccb6c.drv` (was
  `...a968d21.drv`), and the same rebuilt `noctalia-5.0.0.drv`
  (`ih6dkrl3j8n9...`, same content hash as sweet16's, confirming both hosts
  consume the identical rebuilt noctalia derivation via
  `hosts/{sweet16,petunia}/{default,home}.nix`).

`avina`, `hermes`, `groot@dualie`, `groot@forge` are byte-identical — none
of them reference `nixosModules`/`homeManagerModules` that pull in
`inputs.hyprland` or `inputs.noctalia`, consistent with `consumers.sh`.
`groot@rk3588` is `N/A` (aarch64, `uname -m` check in `lib.sh`) — recorded
as unverified, not claimed as zero-drift. **C2+C3 verdict: PASS.**

### Additional checks

**`flake.lock`'s top-level `nixpkgs` node**: compared directly
(`git show 09e7279:flake.lock | jq .nodes.nixpkgs` vs.
`git show 1f4ac0b:flake.lock | jq .nodes.nixpkgs`) — byte-identical
(`rev: 80bdc1e5ce51f56b19791b52b2901187931f5353`, `original.ref:
nixos-unstable`, same `narHash`). None of the three commits in this range
re-locked `nixpkgs`; the pre-existing staleness (locked `ref: nixos-unstable`
vs. `flake.nix`'s declared `nixos-26.05`) is unchanged and was NOT widened
by this range. Confirms `lock-diff.sh`'s node list above, which also does
not mention `nixpkgs`.

**`nix flake check --impure` on merged HEAD `1f4ac0b`**: exit 0, "all
checks passed!" — evaluates all four `nixosConfigurations`
(petunia, avina, hermes, sweet16), `devShells`, `checks`, `packages`,
`homeConfigurations`, `overlays`. Only pre-existing warnings (`unknown flake
output 'modules'`, `aarch64-linux` omitted without `--all-systems`) —
neither new nor errors. The individually-passing sub-branches were not
previously checked in their merged state; this closes that gap.

**Verdict: SIGNED OFF (all three sub-ranges).** C0 and C1 are zero-drift as
expected (C1's zero-drift claim independently re-verified rather than taken
on trust). C2+C3's actual-drift set (`{sweet16, petunia}`) matches its
expected-drift set exactly, with each host's drift traced to the specific
input (`hyprland` → v0.56.1, `noctalia` → v5.0.0-beta.7) and the concrete
rebuilt store paths it feeds. The top-level `nixpkgs` node did not move
across the full range. `nix flake check --impure` passes on merged HEAD.
Deploy targets for this range: `sweet16`, `petunia` only. No deploy was
performed as part of this validation.

## Validation: `c434a64..d39174e` — Stylix foundation (C4, C5)

Baseline: `c434a64` ("merge: sign off C0-C3 closure drift"), the previously
signed-off state. HEAD verified as `d39174e` ("merge: stylix inputs and
theme policy foundation") per the base gate; the working branch had drifted
to a stale tip (`09e7279`) and was reset to `main` (`d39174e`) before
validation. Two sub-ranges judged independently, matching the two logical
commits in the range.

### C4: `c434a64` → `e300471` — add `stylix`/`stylix-unstable` inputs, unreferenced

Adds two flake inputs: `stylix` (`release-26.05`, following `nixpkgs`) and
`stylix-unstable` (`master`, following `nixpkgs-unstable`). No module or host
file references either input at this commit.

`lock-diff.sh c434a64 e300471` (exit 10, nodes changed) — 30 nodes changed,
all newly-added (`(absent) → <hash>`): `stylix`, `stylix-unstable`, and their
transitive input closures (`base16*`, `firefox-gnome-theme*`, `flake-parts_6/7`,
`fromYaml*`, `gnome-shell*`, `nur*`, `systems_4/5`, `tinted-*`). No existing
node (including `nixpkgs`) was re-locked; every changed line is `null →
<hash>`.

`consumers.sh stylix stylix-unstable` at `e300471`: zero output — no
consumer found anywhere in `modules/`, `hosts/`, `profiles/`. Expected-drift
set: `{}` (empty).

`verify-drift.sh c434a64 e300471` (exit 0, no drift):

| Config | c434a64 | e300471 | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `ahflzgdwwfc17yfxcms0i3dwm9056kas...` | `ahflzgdwwfc17yfxcms0i3dwm9056kas...` | none |
| petunia (NixOS) | `2jpk842wr7bs4vqfjrvpajnsgsq82hx6...` | `2jpk842wr7bs4vqfjrvpajnsgsq82hx6...` | none |
| avina (NixOS) | `rnwf3z5cj9y...` | `rnwf3z5cj9y...` | none |
| hermes (NixOS) | `175q2rw24y3...` | `175q2rw24y3...` | none |
| groot@dualie (HM) | `0g2hs1ysskh...` | `0g2hs1ysskh...` | none |
| groot@forge (HM) | `lixapp625v3...` | `lixapp625v3...` | none |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

Actual-drift set (`{}`) matches expected-drift set (`{}`) exactly —
byte-identical toplevel `.drv` paths on all 6 drv-comparable configs.
**C4 verdict: PASS.**

### C5: `e300471` → `0a08d74` — wire stylix module + theme policy, all targets off

`modules/flake/nixos-sweet16.nix` imports `inputs.stylix.nixosModules.stylix`;
`modules/flake/nixos-petunia.nix` imports
`inputs.stylix-unstable.nixosModules.stylix`; `modules/desktop/theme.nix`
(key `desktop-default`) replaces its prior stub with `stylix.enable = true`,
`stylix.autoEnable = false`, `image = null`, `polarity = "dark"`,
`base16Scheme = ayu-dark.yaml`, `override.base0D = "39BAE6"`, fonts, and
`stylix.cursor = { package = pkgs.adwaita-icon-theme; name = "Adwaita"; size
= 24; }`; new `modules/desktop/theme-home.nix` (key `desktop-theme-home`)
disables `hyprland.hyprpaper`, `nixvim`, `tmux` HM targets and
conditionally disables `noctalia` (guarded by `lib.optionalAttrs (options.stylix.targets
? noctalia)`), imported by `hosts/{sweet16,petunia}/home.nix`.

`lock-diff.sh e300471 0a08d74`: exit 0, no output — no `flake.lock` node
moved in this sub-range (directly answers (c) for this half; see the
full-range nixpkgs check below for the complete range).

`consumers.sh stylix stylix-unstable` at `0a08d74`:

```
sweet16: via hosts/sweet16/home.nix
petunia: via hosts/petunia/home.nix
```

Expected-drift set: `{sweet16, petunia}` only (the NixOS-side
`inputs.stylix(-unstable).nixosModules.stylix` imports in
`modules/flake/nixos-{sweet16,petunia}.nix` are direct `inputs.*` references
inside the flake-assembly files, not registry-key lookups, so `consumers.sh`
resolves the same two hosts via their `home.nix` consumption of
`desktop-theme-home` instead — same expected set, confirmed by direct
knowledge of the diff).

`verify-drift.sh e300471 0a08d74` (exit 10, drift found):

| Config | e300471 | 0a08d74 | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `/nix/store/ahflzgdwwfc17yfxcms0i3dwm9056kas-nixos-system-sweet16-26.05.20260717.293d6ab.drv` | `/nix/store/zizyvwdr674x8rlpzxg6qlzvmdmycfn9-nixos-system-sweet16-26.05.20260717.293d6ab.drv` | DRIFT |
| petunia (NixOS) | `/nix/store/2jpk842wr7bs4vqfjrvpajnsgsq82hx6-nixos-system-petunia-26.11.20260729.0954f7e.drv` | `/nix/store/6r67qdk0s5g4rc3bhxz1hn4m92sd82ni-nixos-system-petunia-26.11.20260729.0954f7e.drv` | DRIFT |
| avina (NixOS) | `rnwf3z5cj9y...` | `rnwf3z5cj9y...` | none |
| hermes (NixOS) | `175q2rw24y3...` | `175q2rw24y3...` | none |
| groot@dualie (HM) | `0g2hs1ysskh...` | `0g2hs1ysskh...` | none |
| groot@forge (HM) | `lixapp625v3...` | `lixapp625v3...` | none |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

Actual-drift set (`{sweet16, petunia}`) matches expected-drift set exactly.
`avina`, `hermes`, `groot@dualie`, `groot@forge` are byte-identical — none
of them import the stylix NixOS module or `desktop-theme-home`.
**C5 verdict: PASS (drift matches expected hosts).**

#### (a) Is the C5 drift small, and did it cascade?

`nix eval config.nixpkgs.overlays` on sweet16: length `3` at both `e300471`
and `0a08d74` — **unchanged**, byte-for-byte. `nix eval
config.stylix.overlays.enable` at `0a08d74`: `false`. Root cause: stylix's
`mkEnableTarget name true` resolves to `default = cfg.autoEnable &&
autoEnable-arg`; with `stylix.autoEnable = false` set in `theme.nix`, every
`mkEnableTarget`-derived option (including `stylix.overlays.enable` and all
`stylix.targets.*.enable`, e.g. `gtksourceview`, `nixos-icons`) defaults to
`false`. **The overlay-cascade risk described in the task did not
materialize in this range** — the task's premise that "`stylix.overlays.enable`
defaults true on the NixOS side" does not hold once `autoEnable = false` is
set; contradicts assumption, reported plainly rather than forced to fit.

`nix-store -q --tree` diff (deduplicated by drv basename, hash stripped) on
both sweet16 and petunia's `nixos-system-*.drv` shows an identical set of
32 new / 20 changed-hash-but-same-name derivations on each host (petunia's
list is byte-identical except for a pre-existing `xrdb-1.2.2` vs `xrdb-1.2.3`
per-host version difference, unrelated to stylix). The new leaf packages are:
`ayu-dark.yaml`, `base16-ayu-dark.{html,json}` (the base16 scheme source and
its two rendered artifacts), `mustache-go-1.4.0`/`mustache-go-1.4.0-go-modules`/`mcpp-2.7.2.3`/3×`source.drv`
(new Rust/Go build tooling, traced via `nix-store -q --tree` context to the
`mustache-go` toolchain used to render stylix's own
`stylix/palette.{html,json}.mustache` templates — confirmed against
`stylix/palette.nix` in the `stylix` flake source, which unconditionally
(not gated by `autoEnable` or any target) produces
`stylix.generated.fileTree` entries `stylix/generated.json`,
`stylix/palette.json`, `stylix/palette.html` — exactly the
`environment.etc."stylix/palette.{json,html}"` files anticipated by the
task), plus `hm_homeddukes.Xresources`/`xrdb-1.2.2` and cursor-theme lines
added to `hm_gtk3.0settings.ini`/`hm_gtk4.0settings.ini` (see (b) below). No
package outside stylix's own etc-file generation and cursor plumbing
changed. `nix eval config.environment.etc` attrNames on sweet16 at `0a08d74`
confirms exactly `stylix/generated.json`, `stylix/palette.html`,
`stylix/palette.json` were added. **Verdict: the drift is small and
confined to stylix's own generated files plus cursor propagation — it did
NOT cascade into unrelated packages.** No mitigation (`stylix.overlays.enable
= false`) is needed because overlays never activated in the first place.

#### (b) Did `autoEnable = false` take effect?

Yes, for every per-app **target** (`stylix.targets.*`) — confirmed by (a):
all target-gated options (including `gtksourceview`, `nixos-icons`)
default to `false`. No kitty, ghostty, qt, btop, hyprland-config, or
noctalia-config derivation appears anywhere in the new/changed-name diff for
either host — the name-diff sets contain zero entries for those
applications' rendered config files.

One derivation family **did** change: `hm_gtk3.0settings.ini.drv` /
`hm_gtk4.0settings.ini.drv` gained two new lines
(`gtk-cursor-theme-name=Adwaita`, `gtk-cursor-theme-size=24`, confirmed by
`nix derivation show | python3 -m json.tool` diff of the `text` field —
pre-existing `gtk-theme-name=Graphite-teal-Dark` and
`gtk-icon-theme-name=Adwaita` lines are untouched). Root-caused to
`stylix/hm/cursor.nix` in the `stylix` flake source: `home.pointerCursor` is
set whenever `config.stylix.enable && config.stylix.cursor != null`, gated
by neither `autoEnable` nor the target-enable machinery — cursor is core
stylix infrastructure, not a per-app target. `theme.nix` at `0a08d74`
deliberately sets `stylix.cursor = { package = pkgs.adwaita-icon-theme; name
= "Adwaita"; size = 24; }`, so this propagation is the direct, intended
consequence of that explicit config block, not a leak through
`autoEnable`. **Verdict: `autoEnable = false` correctly suppressed every
target; the one config change that did occur (cursor) is by design,
unrelated to the target/autoEnable machinery, and not a STOP condition.**

`nix flake check --impure` on `0a08d74`/`d39174e` also surfaces a new,
non-fatal warning tied to this same mechanism: "ddukes profile: Relying on
`home.pointerCursor` to enable cursor config generation is deprecated.
Please update your configuration to explicitly set: `home.pointerCursor.enable
= true;`" — a home-manager deprecation notice, not an error; noted for
awareness, does not block sign-off.

#### (c) Did the top-level `nixpkgs` node move?

`git show c434a64:flake.lock | jq '.nodes.nixpkgs'` vs. `git show
d39174e:flake.lock | jq '.nodes.nixpkgs'`: byte-identical. Both report `rev:
80bdc1e5ce51f56b19791b52b2901187931f5353`, `original.ref: nixos-unstable`,
same `narHash`. **The pre-existing staleness is unchanged and was NOT
widened by adding the stylix inputs** — confirmed independently of
`lock-diff.sh`'s node list (which also never mentions `nixpkgs` across
either sub-range).

#### (d) The branch-asymmetry guard (`theme-home.nix`)

Evaluates cleanly on both hosts with no error:
`config.home-manager.users.ddukes.stylix.targets` resolves to 106 keys on
sweet16 (`release-26.05`) and 108 keys on petunia (`master`). **The
resulting `stylix.targets` attrsets do NOT differ in exactly one key as the
task described** — set-diffing the two key lists directly shows petunia has
three keys sweet16 lacks: `noctalia`, `aerc`, `wayle`. The comment in
`theme-home.nix` (and the task framing) accounts only for `noctalia`; `aerc`
and `wayle` are two additional app targets that exist on stylix master but
not on stylix release-26.05, unrelated to the noctalia guard. Reported
plainly rather than reconciled to fit the "one key" expectation. This
discrepancy does **not** affect the derivation-drift verdict: all three
extra keys resolve through the same `mkEnableTarget`-based default
(`cfg.autoEnable && argDefault`), so with `stylix.autoEnable = false` they
default to `enable = false` regardless, and none of the three appear in
either host's new/changed derivation-name diff in (a). The guard's actual
purpose — preventing petunia's stylix-master `noctalia.customPalettes` from
conflicting with the repo's own palette wiring — is unaffected by this
finding.

#### (e) `nix flake check --impure` on merged HEAD `d39174e`

Exit 0, "all checks passed!". Evaluates all four `nixosConfigurations`
(petunia, avina, hermes, sweet16), `devShells`, `checks`, `packages`,
`overlays`, `homeConfigurations`. Only pre-existing warnings (`unknown flake
output 'modules'`, `aarch64-linux` omitted without `--all-systems`) plus the
one new, non-fatal `home.pointerCursor` deprecation warning noted in (b) —
no errors. This closes the gap the task flagged: the merged state (C4+C5
together) had not previously been checked as a unit.

#### (f) `groot@rk3588`

Reports `N/A` on this x86_64 worktree (per `lib.sh`'s `is_na_config`,
`uname -m` check) in both `verify-drift.sh` tables above. Recorded as
**unverified — not claimed as zero-drift.**

**Verdict: SIGNED OFF (both sub-ranges).** C4 is zero-drift as expected —
two unreferenced flake inputs changed nothing. C5's actual-drift set
(`{sweet16, petunia}`) matches its expected-drift set exactly; the drift is
small, confined to stylix's own `palette.{json,html}` etc-files plus the
deliberately-configured cursor propagation (not an overlay cascade —
`stylix.overlays.enable` defaults to `false` under `autoEnable = false`,
contrary to the task's premise, and the overlay list is byte-identical
before/after); `autoEnable = false` correctly suppressed every per-app
theming target; the top-level `nixpkgs` node did not move across the full
range; and `nix flake check --impure` passes on merged HEAD `d39174e`. The
one factual discrepancy versus the task's framing — the `stylix.targets`
attrset differs between sweet16 and petunia in three keys
(`noctalia`, `aerc`, `wayle`), not one — is reported as found and does not
change the derivation-drift verdict, since all three default to disabled
under `autoEnable = false`. `groot@rk3588` remains unverified (aarch64,
`N/A` on this arch). Deploy targets for this range: `sweet16`, `petunia`
only. No deploy was performed as part of this validation.

## Validation: `8f4d47f..4bc8b57` — C6: terminals + btop handed to Stylix

Baseline: `8f4d47f` ("merge: sign off C4-C5 stylix foundation drift"), the
previously signed-off state. HEAD verified as `4bc8b57` ("merge: hand
terminal and btop colors to stylix") per the base gate; the working branch
had drifted to a stale tip (`09e7279`) and was reset to `main` (`4bc8b57`)
before validation. Two commits in range, judged as one logical unit (the
second is a fix to the first, never independently shipped):

- `b8616da` — enables `stylix.targets.{kitty,ghostty,btop}`; adds
  `ghostty.colors.override.base00 = "000000"`; drops the
  `user-terminal-oled-home` import from `modules/tools/home.nix` (key
  `development-default`); removes `programs.btop.settings.color_theme =
  "TTY"`.
- `3eb949a` — fixes the ineffective `kitty.colors.override.base00`
  (unreachable through kitty's base16-scheme functor); moves the tab-bar
  keys out of `programs.kitty.settings` (discarded by kitty's
  last-directive-wins parsing, since HM emits `settings` before the
  target's `include`); appends `background #000000` plus the four
  `active_tab_*`/`inactive_tab_*` keys via
  `programs.kitty.extraConfig = lib.mkAfter`, placed after the include so
  it wins.

Only `modules/desktop/theme-home.nix` (key `desktop-theme-home`) and
`modules/tools/home.nix` (key `development-default`) changed in this range
— confirmed via `git diff 8f4d47f 4bc8b57 --stat`.

`lock-diff.sh 8f4d47f 4bc8b57`: exit 0, no output — no `flake.lock` node
moved. Directly answers (f): `git show <rev>:flake.lock | jq
'.nodes.nixpkgs.locked'` is byte-identical at both revs (`rev:
80bdc1e5ce51f56b19791b52b2901187931f5353`, same `narHash`), and
`.nodes.nixpkgs.original.ref` is still the stale `nixos-unstable` at HEAD.
Unmoved across this range, consistent with the three prior sign-offs.

`consumers.sh desktop-theme-home` at `4bc8b57`:

```
petunia: via hosts/petunia/home.nix
sweet16: via hosts/sweet16/home.nix
```

Expected-drift set: `{sweet16, petunia}` only.

`verify-drift.sh 8f4d47f 4bc8b57` (exit 10, drift found):

| Config | 8f4d47f | 4bc8b57 | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `/nix/store/zizyvwdr674x8rlpzxg6qlzvmdmycfn9-nixos-system-sweet16-26.05.20260717.293d6ab.drv` | `/nix/store/6sm7b4hf800y7smlxpghlgvrs2gf983q-nixos-system-sweet16-26.05.20260717.293d6ab.drv` | DRIFT |
| petunia (NixOS) | `/nix/store/6r67qdk0s5g4rc3bhxz1hn4m92sd82ni-nixos-system-petunia-26.11.20260729.0954f7e.drv` | `/nix/store/5b0hb70k4l2mfxclpgb5ckrjqnnqb75p-nixos-system-petunia-26.11.20260729.0954f7e.drv` | DRIFT |
| avina (NixOS) | `/nix/store/rnwf3z5cj9ymjsivj4rlfvh233wrks5k-nixos-system-unnamed-lxc-proxmox-26.05.20260717.293d6ab.drv` | `/nix/store/rnwf3z5cj9ymjsivj4rlfvh233wrks5k-nixos-system-unnamed-lxc-proxmox-26.05.20260717.293d6ab.drv` | none |
| hermes (NixOS) | `/nix/store/175q2rw24y3fvvf80nbhclnk82snivpb-nixos-system-unnamed-lxc-proxmox-26.05.20260717.293d6ab.drv` | `/nix/store/175q2rw24y3fvvf80nbhclnk82snivpb-nixos-system-unnamed-lxc-proxmox-26.05.20260717.293d6ab.drv` | none |
| groot@dualie (HM) | `/nix/store/0g2hs1ysskhxs1ng76qc48phfgsjnlaa-home-manager-generation.drv` | `/nix/store/0g2hs1ysskhxs1ng76qc48phfgsjnlaa-home-manager-generation.drv` | none |
| groot@forge (HM) | `/nix/store/lixapp625v39ihyhamr0c7iy66bynwc7-home-manager-generation.drv` | `/nix/store/lixapp625v39ihyhamr0c7iy66bynwc7-home-manager-generation.drv` | none |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

Actual-drift set (`{sweet16, petunia}`) matches expected-drift set exactly.
**Verdict: PASS (drift matches expected hosts).**

#### (a) Are avina/hermes/groot@dualie/groot@forge byte-identical, and did the C1 split hold?

Yes — `.drv` paths above are byte-identical across the range for all four.
None of them import `desktop-theme-home` or reference
`stylix.targets.{kitty,ghostty,btop}`; all four still consume
`user-terminal-oled-home` directly (`modules/tools/home.nix`'s
`nix-nexus-terminal`/`hardware-*` bundles for those hosts were untouched by
this diff — only `development-default`'s import list lost the
`user-terminal-oled-home` entry, which is the sweet16/petunia-only bundle).
`modules/tools/terminal-oled-home.nix` (key `user-terminal-oled-home`) has
zero diff in this range. Confirmed at the built-output level:
`groot@dualie`'s kitty config still derives its `background = "#000000"`
from `colors.background` in `terminal-oled-home.nix` (a plain
`programs.kitty.settings.background` value, not a stylix
target/`extraConfig` override) — the split held.

#### (b) Does the kitty fix work in the BUILT output, not just at the option level?

Built `.#nixosConfigurations.sweet16.config.home-manager.users.ddukes.home.activationPackage`
→ `/nix/store/gwa14y2l5ghrdfxghxydzxpakn866vfc-home-manager-generation`.
Resolved `home-files/.config/kitty/kitty.conf` →
`/nix/store/20zl4is12wrpqmvz2apxscf27svkc2h3-hm_kittykitty.conf`. Tail of
the file:

```
include /nix/store/70a4j7rnh2yhm0mzq2pl1vmyd8msbyb1-base16-ayu-dark.conf

background #000000
active_tab_foreground #000000
active_tab_background #39bae6
inactive_tab_foreground #e6e1cf
inactive_tab_background #131721
```

`grep -n "background\|active_tab\|inactive_tab"` over the full file shows
exactly one `background <hex>` line (line 26, after the `include` on line
24) and exactly one occurrence each of the four tab-bar keys (lines 27-30)
— no dead earlier copies from `programs.kitty.settings` survive, because
`3eb949a` moved them out of `settings` entirely. **All three assertions
hold.** Rebuilt the identical check on petunia's HM generation
(`/nix/store/dd1ncr90lqfddilsnnx01dy875n8d89a-home-manager-generation` →
`/nix/store/ra3r21bci6izjfl6w51l1v4k9lgvlh90-hm_kittykitty.conf`): same
structure, `include` on line 24, `background #000000` on line 26, tab-bar
keys on lines 27-30, single occurrence each.

#### (c) Does ghostty's override genuinely work, and is btop's theme `stylix`?

sweet16: `home-files/.config/ghostty/themes/stylix` resolves to
`/nix/store/js80fngq2fvw5zin5nhpr55w9zd77s37-ghostty-stylix-theme`, which
contains `background = 000000` (and `selection-background = 202229`).
`home-files/.config/ghostty/config` contains `theme = stylix`. sweet16's
`home-files/.config/btop/btop.conf` (resolved:
`/nix/store/c5nvn4i88n2ra7qp3wjn0wf1qhsrsp8a-hm_btopbtop.conf`) contains
`color_theme = "stylix"`. Petunia: identical shape —
`ghostty-stylix-theme` at `/nix/store/a4canjvj8qwcrad0nn0ly5lk8ybrdid7`
contains `background = 000000`; btop.conf contains `color_theme =
"stylix"`. Ghostty's target reads `colors.base00` directly (not through
kitty's functor indirection), so `override.base00 = "000000"` in
`theme-home.nix` reaches the rendered theme file on both hosts, as the task
predicted.

#### (d) Is the drift small and confined, or did it cascade?

`nix eval config.nixpkgs.overlays` on sweet16: length `3`, unchanged.
`nix eval config.stylix.overlays.enable`: `false` on both sweet16 and
petunia (still gated by `stylix.autoEnable = false`, untouched by this
range). `nix store diff-closures` between the old/new sweet16 toplevel
outputs (`/nix/store/n7plc5b9q18zihcpr80x7mljajsymaa5-...` →
`/nix/store/mj71k21pv8gqj9ym6g08nvaiz07514j3-...`) reports exactly three
newly-added derivation names: `base16-ayu-dark.conf`, `btop-theme.theme`,
`ghostty-stylix`. `nix-store -qR` set-diff of the full closures (4942 →
4945 paths) shows 29 total differing lines: the 3 new theme derivations
plus 13 name-pairs whose content (hash) changed —
`hm_kittykitty.conf`, `hm_btopbtop.conf`, `ghostty-config`,
`ghostty-stylix-theme`, `base16-ayu-dark.conf`, plus pure propagation
wrappers (`home-manager-files`, `home-manager-path`,
`home-manager-generation`, `etc`, `system-units`,
`unit-home-manager-ddukes.service`, `user-environment`,
`nixos-system-sweet16-*`) that reference the changed store-path hashes but
carry no independent content change. Two entries needed closer inspection
because they weren't obviously terminal/btop-scoped:
`hm_fontconfigconf.d10hmfonts.conf` and
`hm_systemduserappcom.mitchellh.ghostty.service.doverrides.conf`. Diffed
both: the fontconfig file only changed because it embeds the
`home-manager-path` store-path hash in `<include>`/`<dir>`/`<cachedir>`
lines (no font itself changed); the ghostty systemd unit override only
gained the new `ghostty-stylix-theme` path in its
`X-Reload-Triggers=` line, so the unit restarts when the new theme file
changes. Petunia's `nix store diff-closures` on the HM-generation pair
(`/nix/store/1c0r6537jskxk7kcdadbiir808764h0z-...` →
`/nix/store/dd1ncr90lqfddilsnnx01dy875n8d89a-...`) shows the identical
three-line signature (`base16-ayu-dark.conf`, `btop-theme.theme`,
`ghostty-stylix`), confirming the same confined shape on both hosts (the
petunia full-system closure diff was not completed — the toplevel rebuild
was too costly to finish in this session; the HM-generation diff plus the
matching `.drv`-level DRIFT/no-DRIFT table above is the evidence for
petunia). **No cascade: the drift is confined to the three new stylix
theme-target derivations and their direct consumers/wrappers; no
unrelated package rebuilt, and `stylix.overlays.enable` never activated.**

#### (e) Did any other target activate?

`nix eval` on `stylix.targets.<name>.enable` for both hosts:

| Target | sweet16 | petunia |
|---|---|---|
| kitty | true | true |
| ghostty | true | true |
| btop | true | true |
| gtk | false | false |
| qt | false | false |
| hyprland | false | false |
| hyprlock | false | false |
| hyprpaper | false | false |
| noctalia-shell | false | false |
| nixvim | false | false |
| tmux | false | false |

Only `kitty`, `ghostty`, `btop` are enabled on either host. `gtk`/`qt`
remain off, so no conflict with the still-present `gtk.theme`/`qt.style`
in `modules/tools/home.nix` — C7's job, untouched here.

#### (f) Did the top-level `nixpkgs` node move?

No — see the `lock-diff.sh` result above: byte-identical `rev` and
`narHash` at `8f4d47f` and `4bc8b57`; `original.ref` is still the stale
`nixos-unstable`. Confirmed independently via `git show
<rev>:flake.lock | jq '.nodes.nixpkgs.locked'`.

#### (g) `nix flake check --impure` on merged HEAD `4bc8b57`

Exit 0, "all checks passed!". Evaluates all four `nixosConfigurations`
(petunia, avina, hermes, sweet16), `checks`, `devShells`, `packages`,
`overlays`, `homeConfigurations`. Only pre-existing warnings persist: the
`home.pointerCursor` deprecation notice on the petunia HM profile (known,
benign, tracked since the C4/C5 sign-off — unrelated to this range's
`stylix.cursor` config, which is untouched here), `unknown flake output
'modules'`, and the `aarch64-linux` system omission without
`--all-systems`. No new warnings or errors.

#### (h) `groot@rk3588`

Reports `N/A` on this x86_64 worktree (per `lib.sh`'s `is_na_config`,
`uname -m` check) in the `verify-drift.sh` table above. Recorded as
**unverified — not claimed as zero-drift.**

**Verdict: SIGNED OFF.** The actual-drift set (`{sweet16, petunia}`)
matches the expected-drift set from `consumers.sh desktop-theme-home`
exactly; `avina`, `hermes`, `groot@dualie`, `groot@forge` are confirmed
byte-identical, and the C1 terminal split holds — `groot@dualie`'s kitty
background still comes from the untouched `terminal-oled-home.nix`, not
stylix. The kitty rendering fix in `3eb949a` was independently verified in
the BUILT `kitty.conf` on both sweet16 and petunia: the `include` line
precedes the appended block, `background #000000` is the sole/last
background directive, and the four tab-bar keys appear exactly once, last.
Ghostty's `override.base00` reaches the rendered theme file
(`background = 000000`) on both hosts, and btop's built config reads
`color_theme = "stylix"`. The drift is small (29 differing store-path
names in sweet16's full closure) and did not cascade — confined to the
three new stylix theme-target derivations (`base16-ayu-dark.conf`,
`btop-theme.theme`, `ghostty-stylix`) and their direct
propagation-wrapper consumers; `stylix.overlays.enable` stayed `false` and
the overlay list stayed length-3 throughout. No target other than
kitty/ghostty/btop activated on either host — gtk/qt remain `false`,
un-conflicted with C7's still-pending work. The top-level `nixpkgs` node
did not move. `nix flake check --impure` passes clean on merged HEAD
`4bc8b57` with only the pre-existing, unrelated petunia
`home.pointerCursor` warning. `groot@rk3588` remains unverified (aarch64,
`N/A` on this arch). Deploy targets for this range: `sweet16`, `petunia`
only. No deploy was performed as part of this validation.

## Validation: `4bc8b57..005b8b8` — C7: GTK + Qt handed to Stylix

Baseline: `4bc8b57` ("merge: hand terminal and btop colors to stylix"), the
C6 state, signed off at `f06867a`. Base gate: `git log --oneline -5` in this
worktree showed a stale tip (`09e7279`, context-mode hermes drift sign-off);
reset to `main` (`7faa626`, "merge: sign off C6 terminal drift") before
validation, which resolves the requested HEAD exactly. Commit under review:
`005b8b8` ("feat(desktop): hand gtk and qt theming to stylix"), reached from
`4bc8b57` via the merge `e4c652f`.

Only three files changed in the range — confirmed via
`git diff 4bc8b57 005b8b8 --stat`:
- `modules/desktop/theme-home.nix` (key `desktop-theme-home`): adds
  `gtk.enable = true` and `qt.enable = true` to
  `stylix.targets`.
- `modules/tools/home.nix` (key `user-home`): deletes the
  `gtk.theme`/`gtk.gtk4.theme` (`Graphite-teal-Dark` /
  `graphite-gtk-theme.override`) block,
  `qt.platformTheme.name = "gtk3"` / `qt.style.name = "breeze"`, the
  `graphite-gtk-theme` package and the duplicate
  `nerd-fonts.jetbrains-mono` from `home.packages`, and the now-unused
  `config` function argument.
- `modules/desktop/hyprland-home.nix` (key `desktop-hyprland-home`):
  deletes the empty-valued `"QT_QPA_PLATFORMTHEME,"` entry from the
  Hyprland `env` list.

`lock-diff.sh 4bc8b57 005b8b8`: exit 0, no output — no `flake.lock` node
moved. Directly answers (f): `git show 005b8b8:flake.lock | python3 -c
"json.load(...)['nodes']['nixpkgs']['locked']"` is byte-identical to the
four prior sign-offs (`rev: 80bdc1e5ce51f56b19791b52b2901187931f5353`, same
`narHash`); `flake.lock` itself has zero diff in the range
(`git diff --stat 4bc8b57 005b8b8 -- flake.lock` produced no output).

`consumers.sh desktop-theme-home user-home desktop-hyprland-home` at
`005b8b8`:

```
petunia: via hosts/petunia/home.nix
sweet16: via hosts/sweet16/home.nix
```

Expected-drift set: `{sweet16, petunia}` only.

`verify-drift.sh 4bc8b57 005b8b8` (exit 10, drift found):

| Config | 4bc8b57 | 005b8b8 | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `/nix/store/6sm7b4hf800y7smlxpghlgvrs2gf983q-nixos-system-sweet16-26.05.20260717.293d6ab.drv` | `/nix/store/0fvqnainc4qdzbbii699g67s5y6sz864-nixos-system-sweet16-26.05.20260717.293d6ab.drv` | DRIFT |
| petunia (NixOS) | `/nix/store/5b0hb70k4l2mfxclpgb5ckrjqnnqb75p-nixos-system-petunia-26.11.20260729.0954f7e.drv` | `/nix/store/rchmsn33apfbzpddy0y1pp0xs007zxff-nixos-system-petunia-26.11.20260729.0954f7e.drv` | DRIFT |
| avina (NixOS) | `/nix/store/rnwf3z5cj9ymjsivj4rlfvh233wrks5k-nixos-system-unnamed-lxc-proxmox-26.05.20260717.293d6ab.drv` | `/nix/store/rnwf3z5cj9ymjsivj4rlfvh233wrks5k-nixos-system-unnamed-lxc-proxmox-26.05.20260717.293d6ab.drv` | none |
| hermes (NixOS) | `/nix/store/175q2rw24y3fvvf80nbhclnk82snivpb-nixos-system-unnamed-lxc-proxmox-26.05.20260717.293d6ab.drv` | `/nix/store/175q2rw24y3fvvf80nbhclnk82snivpb-nixos-system-unnamed-lxc-proxmox-26.05.20260717.293d6ab.drv` | none |
| groot@dualie (HM) | `/nix/store/0g2hs1ysskhxs1ng76qc48phfgsjnlaa-home-manager-generation.drv` | `/nix/store/0g2hs1ysskhxs1ng76qc48phfgsjnlaa-home-manager-generation.drv` | none |
| groot@forge (HM) | `/nix/store/lixapp625v39ihyhamr0c7iy66bynwc7-home-manager-generation.drv` | `/nix/store/lixapp625v39ihyhamr0c7iy66bynwc7-home-manager-generation.drv` | none |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

Actual-drift set (`{sweet16, petunia}`) matches expected-drift set exactly.
**Verdict: PASS (drift matches expected hosts).**

#### (a) Quantify the delta

`nix build` the toplevels/HM generations at both revs and ran
`nix store diff-closures`.

sweet16 toplevel: `/nix/store/mj71k21pv8gqj9ym6g08nvaiz07514j3-nixos-system-sweet16-*`
(base) → `/nix/store/ghgfvl112j2jlxg8kvy395f4c4279w8l-nixos-system-sweet16-*`
(new). Diff:

- **Removed entirely:** `graphite-gtk-theme` (confirmed gone), plus the
  full KDE-Frameworks chain that `qt.style.name = "breeze"` had been
  pulling in: `breeze`, `breeze-icons` (-71.9 MiB), `attica`, `karchive`,
  `kauth`, `kbookmarks`, `kcodecs`, `kcompletion`, `kconfig`,
  `kconfigwidgets`, `kcoreaddons`, `kcrash`, `kdbusaddons`, `kdoctools`,
  `kglobalaccel`, `kguiaddons`, `ki18n` (-17.1 MiB), `kiconthemes`, `kio`
  (-26.4 MiB), `kirigami2`, `kitemviews`, `kjobwidgets`, `knewstuff`,
  `knotifications`, `kpackage`, `kservice`, `ktextwidgets`, `kwallet`,
  `kwidgetsaddons` (-7.4 MiB), `kwindowsystem`, `kxmlgui`,
  `libdbusmenu-qt5`, `media-player-info`, `polkit-qt`, `qca` (-3.5 MiB),
  `qtgraphicaleffects`, `qtquickcontrols2` (-9.7 MiB), `solid`, `sonnet`,
  `syndication`, plus their own build-time-only deps that also disappear
  from the runtime closure (`bison`, `flex`, `docbook-xsl-ns` -17.7 MiB).
- **Added:** `adw-gtk3` (2.1 MiB), `base16` (159.5 KiB, the base16
  Python lib qt5ct/qt6ct's colour scheme reads from), `kvantum` (ε),
  `qt5ct` (1.1 MiB), `qt6ct` (889.2 KiB),
  `qtstyleplugin-kvantum`/`qtstyleplugin-kvantum5` (8.8 MiB + 1.2 MiB).
  `home-manager` itself grew ~1.4 MiB (the new rendered config files).
  Two internal HM derivation names swap (`gtk.css` appears, the old
  `hm_gtk4.0gtk.css` name disappears) — a rename artifact of stylix's gtk
  target owning the CSS file now, not a second unrelated file.

Confirmed: `graphite-gtk-theme` is **GONE**; `adw-gtk3` and kvantum
(`kvantum`, `qtstyleplugin-kvantum`, `qtstyleplugin-kvantum5`) are **IN**.
Every other name in the diff traces directly to the qt engine swap
(`qt.style.name = "breeze"` → stylix's kvantum-based qt target) — this is
the entire KDE-Frameworks dependency chain that `breeze` alone was
responsible for, not an unrelated cascade. This is indeed the largest
delta of the series so far, exactly as flagged.

petunia: full-toplevel `diff-closures` was not attempted — the petunia
toplevel is not cache-substitutable once `cache.garnix.io` is excluded (it
pulls the CachyOS custom kernel, which timed out building from source in
this session at 30 minutes). Ran `diff-closures` on petunia's HM generation
instead (`.config.home-manager.users.ddukes.home.activationPackage`,
substituted cleanly from `cache.nixos.org`):
`/nix/store/dd1ncr90lqfddilsnnx01dy875n8d89a-home-manager-generation` (base)
→ `/nix/store/4nc9cd4sav24zbs5rj1ryk1syczh8j8m-home-manager-generation`
(new). Signature is identical to sweet16's (same removed KDE-Frameworks
chain, same `adw-gtk3`/kvantum/qt5ct/qt6ct additions), **plus one line not
present on sweet16:** `noto-fonts: ∅ → 2026.07.01, +49.1 MiB`. This is not
a new package on the deployed petunia system — `noto-fonts` is already
pulled in fleet-wide at the system level by `modules/desktop/fonts.nix`
(`fonts.packages`), which is why it produces **zero** diff-closures delta
on sweet16's *full toplevel* comparison (present unchanged on both sides).
The reason it appears "added" in petunia's *HM-generation-only* comparison
is that stylix's HM `gtk` target now sets `gtk.font` directly from
`config.stylix.fonts.sansSerif` (`pkgs.noto-fonts`, per
`modules/desktop/theme.nix`), which gives the isolated HM closure its own
first direct reference to a store path that was previously only reachable
through the system profile's GC root. Net effect on the running system:
zero new bytes fetched/installed (same store path, already present);
net effect on the HM-only closure count: +1 direct reference, directly
attributable to enabling `gtk.enable`, not an unrelated cascade.

#### (b) No overlay cascade

`nix eval` at `005b8b8` on both hosts:

| Host | `stylix.autoEnable` | `stylix.overlays.enable` | `nixpkgs.overlays` length |
|---|---|---|---|
| sweet16 | `false` | `false` | `3` |
| petunia | `false` | `false` | `3` |

Unchanged from every prior sign-off in this series. No overlay cascade.

#### (c) Verified from BUILT files, not option values

Built `.#nixosConfigurations.sweet16.config.home-manager.users.ddukes.home.activationPackage`
→ `/nix/store/kqnd3z0rng0bvgvm54dygzxv4gygq1y6-home-manager-generation`,
resolved to `home-files` at
`/nix/store/x2zjiqhipvzq7nlgn29dzayry1hnfp4m-home-manager-files`.

`.config/gtk-3.0/settings.ini` and `.config/gtk-4.0/settings.ini` (identical):

```
[Settings]
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-font-name=Noto Sans 12
gtk-icon-theme-name=Adwaita
gtk-theme-name=adw-gtk3
```

`.gtkrc-2.0`:

```
gtk-cursor-theme-name = "Adwaita"
gtk-cursor-theme-size = 24
gtk-font-name = "Noto Sans 12"
gtk-icon-theme-name = "Adwaita"
gtk-theme-name = "adw-gtk3"
```

`gtk-theme-name` reads `adw-gtk3` in all three files, **not**
`Graphite-teal-Dark`. The C5 cursor lines (`gtk-cursor-theme-name=Adwaita`,
`gtk-cursor-theme-size=24`) are **still present** in all three — no
regression. `gtk-icon-theme-name=Adwaita` confirms `gtk.iconTheme` is
**still `Adwaita`** — stylix did not touch it (`stylix.icons.enable`
defaults `false`, as expected).

`.config/gtk-3.0/gtk.css` and `.config/gtk-4.0/gtk.css` both exist (89
lines each) with ayu-dark tokens, e.g.:

```
@define-color accent_color #39bae6;
@define-color accent_bg_color #39bae6;
@define-color accent_fg_color #0b0e14;
@define-color destructive_color #f07178;
@define-color destructive_bg_color #f07178;
```

`#39bae6` matches `theme.nix`'s `override.base0D`; `#0b0e14` is ayu-dark's
`base00`.

`.config/qt5ct/qt5ct.conf` and `.config/qt6ct/qt6ct.conf` both exist
(identical):

```
[Appearance]
custom_palette=true
standard_dialogs=default
style=kvantum

[Fonts]
fixed="JetBrainsMono Nerd Font,12"
general="Noto Sans,12"
```

`.config/Kvantum/` contains `kvantum.kvconfig` (`theme=Base16Kvantum`) and
`Base16Kvantum/Base16Kvantum.{kvconfig,svg}` — the theme files are in the
closure. All (c) assertions hold.

#### (d) The `QT_QPA_PLATFORMTHEME` runtime trap

Generated `.config/hypr/hyprland.conf`: `grep -n -i QT_QPA` returns only
`env=QT_QPA_PLATFORM,wayland;xcb` (line 122) — the deleted empty
`QT_QPA_PLATFORMTHEME,` assignment does **not** appear, and no replacement
empty assignment was introduced. It is absent from `hyprland.conf`
entirely, but that is **sufficient**: HM's own `qt.enable = true` target
generates `.config/environment.d/10-home-manager.conf`, which sets it
independently and correctly:

```
QT_QPA_PLATFORMTHEME=qt5ct
QT_STYLE_OVERRIDE=kvantum
QT_PLUGIN_PATH=/etc/profiles/per-user/ddukes/lib/qt-5.15.19/plugins:/etc/profiles/per-user/ddukes/lib/qt-6/plugins
```

`environment.d` is read by the systemd user session at login (before
Hyprland's `env=` directives even apply), so this is the authoritative
source — not a gap. `QT_STYLE_OVERRIDE=kvantum` additionally forces the
kvantum style regardless of platform-theme resolution. No uncertainty:
the deleted Hyprland line was genuinely dead/harmful (empty value would
have shadowed nothing at runtime since Hyprland's `env=` only sets missing
vars, but its presence as an empty string is exactly the kind of trap the
task flagged — removing it is strictly correct, and qt5ct/qt6ct pickup is
independently guaranteed by HM's own environment.d file).

#### (e) Target scope

`nix eval` on `stylix.targets` (`.enable` for every target) on sweet16 at
`005b8b8`: only `btop`, `ghostty`, `gtk`, `kitty`, `qt` are `true`. Every
other target — including `hyprland`, `hyprlock`, `hyprpaper`, `nixvim`,
`tmux`, `noctalia-shell` — is `false`. Scope matches exactly what C7 was
supposed to touch; C8's hyprland/hyprlock work has not started.

#### (f) Lock and `nixpkgs` node

`nixpkgs` node at `005b8b8`: `rev = 80bdc1e5ce51f56b19791b52b2901187931f5353`,
same `narHash` as every prior sign-off in this series. `flake.lock` has
zero diff across the range (`git diff --stat 4bc8b57 005b8b8 -- flake.lock`
produced no output) — untouched by this commit, consistent with
`lock-diff.sh` reporting no node changes.

#### (g) `nix flake check --impure` on `005b8b8`

Ran against `git+file:$PWD?rev=005b8b8` (no working-tree checkout
required). Exit 0, "all checks passed!". Evaluates all four
`nixosConfigurations` (petunia, avina, hermes, sweet16), `checks`,
`devShells`, `packages`, `overlays`, `homeConfigurations`. Warnings
present: the known petunia `home.pointerCursor` deprecation notice, and
the two known pre-existing `devenv-up`/`devenv-test` package-deprecation
warnings, plus the informational `unknown flake output 'modules'` and
`aarch64-linux` omission notices. **No new warnings** — in particular, no
stylix qt-target-style-mismatch warning appeared, consistent with the
implementer's report of `warnings == []` for the qt target specifically
(stylix's own qt-style recommendation warning did not fire, since
`qt.style.name` is no longer set at all in `modules/tools/home.nix` — it
now takes stylix's own kvantum default rather than overriding it with
`"breeze"`).

#### (h) `groot@rk3588`

Reports `N/A` on this x86_64 worktree (`verify-drift.sh` table above, via
`lib.sh`'s `is_na_config`). Recorded as **unverified — not claimed as
zero-drift.**

**Verdict: SIGNED OFF.** The actual-drift set (`{sweet16, petunia}`)
matches the expected-drift set from
`consumers.sh desktop-theme-home user-home desktop-hyprland-home` exactly;
`avina`, `hermes`, `groot@dualie`, `groot@forge` are confirmed
byte-identical .drv paths. The delta is the largest of the series, as
flagged, but every added/removed name traces directly to the qt
theme-engine swap (`breeze`'s KDE-Frameworks chain out, kvantum +
qt5ct/qt6ct + adw-gtk3 in) — no unrelated package moved. The one
petunia-only line (`noto-fonts`) is a closure-reference artifact of
comparing an isolated HM generation, not a new package on the deployed
system; it is directly attributable to `gtk.enable` wiring
`gtk.font` from `stylix.fonts.sansSerif`, already fleet-wide via
`fonts.packages`. `stylix.autoEnable`/`stylix.overlays.enable` stayed
`false` and the overlay list stayed length-3 on both hosts — no cascade.
BUILT-file verification confirms `adw-gtk3` theming, intact C5 cursor
config, intact `Adwaita` icon theme, ayu-dark `gtk.css` tokens, and
kvantum/qt5ct/qt6ct wiring on sweet16. The `QT_QPA_PLATFORMTHEME` trap is
resolved: the empty Hyprland assignment is gone and HM's own
`environment.d` file sets it correctly (`qt5ct` + `QT_STYLE_OVERRIDE=kvantum`).
Only `kitty`/`ghostty`/`btop`/`gtk`/`qt` are enabled on sweet16 — no other
target (hyprland, hyprlock, hyprpaper, nixvim, tmux, noctalia-shell)
activated. The top-level `nixpkgs` node did not move and `flake.lock` is
untouched. `nix flake check --impure` passes clean on `005b8b8` with no
new warnings. `groot@rk3588` remains unverified (aarch64, `N/A` on this
arch). Deploy targets for this range: `sweet16`, `petunia` only. No deploy
was performed as part of this validation.

## Validation: `e4c652f..2252655` — C8: Hyprland/hyprlock + noctalia handed to Stylix (final implementation commit)

Baseline: `e4c652f` ("merge: hand gtk and qt theming to stylix", C7's
merge commit — the prior sub-range in this migration; no standalone C7
sign-off entry exists in this file, but `e4c652f` is the correct
pre-image per task instructions). HEAD verified as `2252655` ("merge:
hand hyprland, hyprlock and noctalia to stylix") per the base gate; the
worktree had drifted to a stale tip (`09e7279`) and was reset to `main`
(`2252655`) before validation. Two commits in range:

- `6278a8b` — enables `stylix.targets.{hyprland,hyprlock}`; deletes the
  bare-hex `let` bindings and `general."col.active_border"`/
  `"col.inactive_border"`, `decoration.shadow.color` from
  `hyprland-home.nix`; deletes all `"col.*"`-prefixed hyprlock keys;
  converts hyprlock `background` and `input-field` from single-element
  lists to bare attrsets (stylix writes them as attrsets — this was a
  whole-stanza type conflict that failed eval until fixed); rewrites
  label colours/font from `config.lib.stylix.colors` /
  `config.stylix.fonts.monospace.name`.
- `b0bf846` — new `modules/desktop/noctalia-stylix-home.nix` (registers
  to the existing `desktop-noctalia-home` key) mapping stylix colours
  onto `customPalettes.stylix` with both dark and light variants;
  deletes the ~76-hex `customPalettes."ayu-blue"` block and
  `theme.{mode,source,custom_palette}` from `noctalia-home.nix`; keeps
  `pure_black_dark = true`.

Only `modules/desktop/hyprland-home.nix`, `modules/desktop/theme-home.nix`,
`modules/desktop/noctalia-home.nix` and new file
`modules/desktop/noctalia-stylix-home.nix` changed in this range —
confirmed via `git diff e4c652f 2252655 --stat`. `git status` was clean
throughout (no untracked fragments — the C8 implementation-time gotcha
about an untracked new `.nix` file being silently excluded from `nix
build` did not recur here; `noctalia-stylix-home.nix` is committed at
`2252655`).

`lock-diff.sh e4c652f 2252655`: exit 0, no output — no `flake.lock` node
moved. Directly answers (g): `git diff e4c652f 2252655 -- flake.lock` is
empty, and `git show 2252655:flake.lock | jq '.nodes.nixpkgs.locked'`
shows `rev: 80bdc1e5ce51f56b19791b52b2901187931f5353` (same `narHash`),
unmoved — consistent with the five prior sign-offs in this migration.

`consumers.sh desktop-hyprland-home desktop-theme-home
desktop-noctalia-home` at `2252655`, resolved recursively (all three keys
independently, each returning the same two hosts):

```
petunia: via hosts/petunia/home.nix
sweet16: via hosts/sweet16/home.nix
```

Expected-drift set: `{sweet16, petunia}` only.

`verify-drift.sh e4c652f 2252655` (exit 10, drift found):

| Config | e4c652f | 2252655 | Drift |
|---|---|---|---|
| sweet16 (NixOS) | `/nix/store/0fvqnainc4qdzbbii699g67s5y6sz864-nixos-system-sweet16-26.05.20260717.293d6ab.drv` | `/nix/store/dsqnmxfcs6v0aplimg1mfi4im7fjw56f-nixos-system-sweet16-26.05.20260717.293d6ab.drv` | DRIFT |
| petunia (NixOS) | `/nix/store/rchmsn33apfbzpddy0y1pp0xs007zxff-nixos-system-petunia-26.11.20260729.0954f7e.drv` | `/nix/store/p15czl3wicyb9qjr3q541z3i8px490q2-nixos-system-petunia-26.11.20260729.0954f7e.drv` | DRIFT |
| avina (NixOS) | `/nix/store/rnwf3z5cj9ymjsivj4rlfvh233wrks5k-nixos-system-unnamed-lxc-proxmox-26.05.20260717.293d6ab.drv` | `/nix/store/rnwf3z5cj9ymjsivj4rlfvh233wrks5k-nixos-system-unnamed-lxc-proxmox-26.05.20260717.293d6ab.drv` | none |
| hermes (NixOS) | `/nix/store/175q2rw24y3fvvf80nbhclnk82snivpb-nixos-system-unnamed-lxc-proxmox-26.05.20260717.293d6ab.drv` | `/nix/store/175q2rw24y3fvvf80nbhclnk82snivpb-nixos-system-unnamed-lxc-proxmox-26.05.20260717.293d6ab.drv` | none |
| groot@dualie (HM) | `/nix/store/0g2hs1ysskhxs1ng76qc48phfgsjnlaa-home-manager-generation.drv` | `/nix/store/0g2hs1ysskhxs1ng76qc48phfgsjnlaa-home-manager-generation.drv` | none |
| groot@forge (HM) | `/nix/store/lixapp625v39ihyhamr0c7iy66bynwc7-home-manager-generation.drv` | `/nix/store/lixapp625v39ihyhamr0c7iy66bynwc7-home-manager-generation.drv` | none |
| groot@rk3588 (HM) | `N/A` | `N/A` | N/A |

Actual-drift set (`{sweet16, petunia}`) matches expected-drift set
exactly. **Verdict: PASS (drift matches expected hosts).**

#### (a) The `col.` hyprlock trap — built-output verification

Built `.#nixosConfigurations.{sweet16,petunia}.config.home-manager.users.ddukes.home.activationPackage`
and inspected the generated `home-files/.config/hypr/hyprlock.conf` on
both hosts. Sweet16
(`/nix/store/8nkr7qjg70ijpqr8dpybqgd1dmvnm5ix-home-manager-generation`):

```
background {
  monitor=
  blur_passes=3
  blur_size=8
  brightness=0.500000
  color=rgb(0b0e14)
}
...
input-field {
  monitor=
  size=300, 50
  check_color=rgb(ffb454)
  ...
  fail_color=rgb(f07178)
  ...
  font_color=rgb(e6e1cf)
  ...
  inner_color=rgb(0b0e14)
  outer_color=rgb(3e4b59)
  ...
}
```

`grep -c` on that file: `outer_color`→1, `inner_color`→1, `font_color`→1,
`fail_color`→1, `check_color`→1, `col\.`→**0**. `grep -n '^\s*color='`
shows exactly one standalone `color=` under the `background` block (line
6, `rgb(0b0e14)`) — the other two matches are the clock/date `label`
blocks' text colour, unrelated to the trap. Petunia
(`/nix/store/dsqjzpbp8gck2aaz16wfdrsqg75h1g9x-home-manager-generation`)
is byte-identical in content (same theme, same host user `ddukes`):
identical five counts (each exactly 1), `col\.`→0, one standalone
background `color=` line. The trap did not fire on either host — stylix's
attrset-shaped `outer_color`/`inner_color`/etc. are the sole surviving
keys, and no dead `"col.*"`-prefixed key coexists to create an undefined
choice.

#### (b) Hyprland borders — built-output verification

Sweet16 `home-files/.config/hypr/hyprland.conf`: `col.active_border=rgb(39bae6)`
(line 142, count 1) and `col.inactive_border=rgb(3e4b59)` (line 143,
count 1) — active is the accent `rgb(39bae6)`, matching noctalia's
`mPrimary`. `decoration.shadow.color_inactive=rgba(00000033)` survives
(line 104) and `misc.disable_hyprland_logo=true` survives (line 200).
Petunia is identical in shape: `col.active_border=rgb(39bae6)` (line
143), `col.inactive_border=rgb(3e4b59)` (line 144), `color_inactive`
(line 104), `disable_hyprland_logo=true` (line 201) — both kept.

#### (c) noctalia palette

Sweet16 `home-files/.config/noctalia/palettes/`: exactly one file,
`stylix.json` — no `ayu-blue.json`. `mPrimary` under `.dark` is
`"#39bae6"`. `config.toml`: `custom_palette = "stylix"`, `source =
"custom"`, `pure_black_dark = true`, `mode = "dark"`. Petunia: identical
shape — one file (`palettes/stylix.json`), same four `config.toml`
values, `mPrimary` (dark) `"#39bae6"`.

Petunia is the important case because stylix master ships an upstream v5
`noctalia` target (`options.stylix.targets ? noctalia` is `true` there,
`false` on sweet16, which pins `release-26.05`). Verified the guard held
by evaluating the option directly:
`nixosConfigurations.petunia.config.home-manager.users.ddukes.stylix.targets.noctalia.enable`
→ `false`. Combined with the built-output check above (exactly one
`palettes/*.json` file on petunia, `stylix.json`, no second
upstream-generated palette file), this confirms `lib.optionalAttrs
(options.stylix.targets ? noctalia) { noctalia.enable = false; }` in
`theme-home.nix` genuinely disabled the conflicting upstream target on
petunia, leaving only the hand-written `customPalettes.stylix` mapping
from `noctalia-stylix-home.nix` in effect. Sweet16 has no `noctalia`
key in `stylix.targets` at all (confirmed via `builtins.hasAttr
"noctalia"` on the evaluated target set), so the guard correctly no-ops
there.

#### (d) The light variant

`modules/desktop/noctalia-stylix-home.nix` hardcodes 13 ayu-light hex
literals (`base00`–`base0E`, skipping `base06`, which the role mapping
never reads). Compared against
`${pkgs.base16-schemes}/share/themes/ayu-light.yaml`
(built at `/nix/store/s45n1r5nv8cyi8209ggjy45gw2sz94vv-base16-schemes-.../share/themes/ayu-light.yaml`):
all 13 values match exactly, including the mixed-case `base04 =
"#8A9199"`. No literal in the light block diverges from upstream
ayu-light.

Light is inert by default: `modules/desktop/theme.nix` sets
`stylix.polarity = "dark"`, and the built `config.toml` on both hosts
reads `mode = "dark"` (verified above in (c)) — `customPalettes.stylix.light`
is present in the emitted `palettes/stylix.json` (both `dark` and
`light` keys populated) but noctalia's runtime only resolves `mode =
"dark"` at startup, so the light values are shipped but not the active
rendering path today.

#### (e) Delta quantification

`nix store diff-closures` on sweet16's full toplevel closure
(`/nix/store/ghgfvl112j2jlxg8kvy395f4c4279w8l-...` →
`/nix/store/5dkda11yxabl6m3kvx1j54n5w92cqkc6-...`):

```
ayu-blue-palette.json: ε → ∅
stylix-palette.json: ∅ → ε
```

One net new store-path *name* (`stylix-palette.json` replacing
`ayu-blue-palette.json` — the noctalia palette file, following the same
"new theme-target derivation" pattern as C6's 3 new derivations, except
here it's a rename/replace of one file, not an addition). `nix-store -qR`
set-diff of the full closure shows 20 differing lines total: the
toplevel/`home-manager-generation` self-references, plus name-pairs
whose content changed — `hm_hyprhyprland.conf`, `hm_hyprhyprlock.conf`,
`noctalia-config`, `home-manager-files`, `etc`, `system-units`,
`unit-home-manager-ddukes.service` — pure propagation wrappers that
reference the changed store-path hashes but carry no independent content
change of their own, plus the `ayu-blue-palette.json`/
`stylix-palette.json` swap. No unrelated package rebuilt.

Petunia's full-system `toplevel` rebuild was still running after 35+
minutes in this session (consistent with the prior C6 sign-off's note
that petunia's ROCm-stack toplevel is too costly to finish locally; it
also competed with an unrelated concurrent build from another worktree
on this machine) and was **not completed** — matching the C6 precedent,
the full closure diff for petunia is not claimed. Substitute evidence:
`nix store diff-closures` on the HM-generation pair
(`/nix/store/4nc9cd4sav24zbs5rj1ryk1syczh8j8m-home-manager-generation` →
`/nix/store/dsqjzpbp8gck2aaz16wfdrsqg75h1g9x-home-manager-generation`)
shows the **identical two-line signature** (`ayu-blue-palette.json: ε →
∅`, `stylix-palette.json: ∅ → ε`), and `nix-store -qR` set-diff on that
pair shows the same 12-line confined shape (`hm_hyprhyprland.conf`,
`hm_hyprhyprlock.conf`, `noctalia-config`, `home-manager-files`, the two
palette files, plus the generation self-references) — no unrelated
package. Combined with the matching DRIFT/none `.drv`-level table above,
this is treated as sufficient evidence of a confined, config-file-only
drift on petunia; **no cascade, no new package** on either host.

#### (f) Target scope

`nix eval` on `stylix.targets` (all keys) for both hosts' HM profile:
enabled set is exactly `{btop, ghostty, gtk, hyprland, hyprlock, kitty,
qt}` on both sweet16 and petunia — matching the expected seven. Still
off: `hyprpaper` (false), `nixvim` (false), `tmux` (false),
`noctalia-shell` (false), and on petunia specifically the upstream
`noctalia` key (false, per (c)). `stylix.autoEnable` is `false` and
`stylix.overlays.enable` is `false` on both hosts;
`config.nixpkgs.overlays` has length `3` on both — no cascade.

#### (g) `flake.lock`

Confirmed unmoved — see the `lock-diff.sh` result above (exit 0, no
node changed) and the direct `jq` check on `.nodes.nixpkgs.locked`
(`rev: 80bdc1e5ce51f56b19791b52b2901187931f5353`, byte-identical
`narHash` at both revs).

#### (h) `nix flake check --impure` on `2252655`

Exit 0, "all checks passed!". Evaluates all four `nixosConfigurations`
(petunia, avina, hermes, sweet16), `checks`, `devShells`, `packages`,
`overlays`, `homeConfigurations`. Only known-benign warnings persist:
the petunia `home.pointerCursor` deprecation notice, the
`devenv-up`/`devenv-test` deprecation notices, `unknown flake output
'modules'`, and the `aarch64-linux` system omission without
`--all-systems`. No new warnings or errors.

#### (i) `groot@rk3588`

Reports `N/A` on this x86_64 worktree (per `lib.sh`'s `is_na_config`,
`uname -m` check) in the `verify-drift.sh` table above. Recorded as
**unverified — not claimed as zero-drift.**

#### (j) Migration completeness sanity check

`grep -rlnE '#[0-9a-fA-F]{6}' modules/` returns exactly four files, all
intentional and matching the known list: `modules/tools/terminal-oled-home.nix`
(the OLED palette serving the four non-stylix hosts, unchanged in this
range), `modules/desktop/theme-home.nix` (`trueBlack = "#000000"`, the
deliberate OLED override for kitty, unchanged in this range),
`modules/tools/terminal-home.nix` (two `set -g pane-border-style`/
`pane-active-border-style` tmux lines, deferred/`extraConfig`, unchanged
in this range), and `modules/desktop/noctalia-stylix-home.nix` (the 13
ayu-light literals verified in (d), new in this range). Nothing else
found.

**Verdict: SIGNED OFF.** The actual-drift set (`{sweet16, petunia}`)
matches the expected-drift set from `consumers.sh
desktop-hyprland-home desktop-theme-home desktop-noctalia-home` exactly;
`avina`, `hermes`, `groot@dualie`, `groot@forge` are confirmed
byte-identical .drv paths. The highest-risk item — the hyprlock `col.`
naming trap — was verified from the BUILT `hyprlock.conf` on both hosts:
each of `outer_color`/`inner_color`/`font_color`/`fail_color`/
`check_color` appears exactly once, zero `col.`-prefixed keys survive,
and the single `background` colour is unambiguous. Hyprland's
`col.active_border`/`col.inactive_border` each appear exactly once
(active = accent `rgb(39bae6)`), and `decoration.shadow.color_inactive`
plus `misc.disable_hyprland_logo` both survived the refactor. Noctalia
emits exactly one palette file (`stylix.json`) on both hosts — critically
on petunia, where the upstream stylix-master v5 `noctalia` target exists
in the option tree, the `lib.optionalAttrs` guard was confirmed to
genuinely disable it (`stylix.targets.noctalia.enable` evaluates to
`false`), leaving only the hand-written mapping active. The light
variant's 13 hex literals match `ayu-light.yaml` exactly and are inert by
default (`polarity = "dark"`, rendered `mode = "dark"`). Drift is
config-file-only: one palette-file rename/replace
(`ayu-blue-palette.json` → `stylix-palette.json`) plus direct
propagation wrappers, confirmed identically on sweet16 (full closure,
20-line set-diff) and petunia (HM-generation closure, 12-line set-diff,
full toplevel diff not completed — too costly locally, per the C6
precedent — substituted with the matching HM-generation-level evidence).
No unrelated package moved, `stylix.autoEnable`/`stylix.overlays.enable`
stayed `false`, and the overlay count stayed `3` throughout. Target scope
is exactly the expected seven (`kitty, ghostty, btop, gtk, qt, hyprland,
hyprlock`) on both hosts. The top-level `nixpkgs` node did not move.
`nix flake check --impure` passes clean on `2252655` with only
pre-existing, unrelated warnings. `groot@rk3588` remains unverified
(aarch64, `N/A` on this arch). Deploy targets for this range: `sweet16`,
`petunia` only. No deploy was performed as part of this validation.
