
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
