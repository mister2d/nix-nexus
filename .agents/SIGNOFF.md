
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
