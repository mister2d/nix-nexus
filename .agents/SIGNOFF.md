
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
