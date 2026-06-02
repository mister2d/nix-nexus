# .agents/phase-A.md — Deferred Module Merge

> **Precondition:** `.agents/validation.md` baseline capture is complete.
> All host `.drv` paths are recorded in `.agents/SIGNOFF.md` before any
> file in this phase is touched.
>
> **Goal.** Switch both `flake.modules` registries from `lib.types.raw` to
> `lib.types.deferredModule`. Then rename each leaf module in the five
> identified groups to its shared target name. Delete all aggregator files
> that become redundant. The result: hosts reference the same target names
> as before; the intermediate named layers and their aggregator files are gone.
>
> **Authority.** Dendritic pattern (`flake.modules.*` merge semantics) and
> NixOS module system (`lib.types.deferredModule`). Re-read the deferredModule
> type definition in `lib/types.nix` (nixpkgs) before starting.

---

## 1. Why `deferredModule` enables this

`lib.types.raw` has no merge function. Two modules setting the same attribute
in `flake.modules.nixos` conflict at evaluation time. That is why aggregators
exist: each leaf registers under a unique name, and the aggregator collects
them all into one import list under the target name.

`lib.types.deferredModule` has a merge function that collects all definitions
for the same key into `{ _type = "merge"; contents = [def1 def2 ...]; }`.
The NixOS module system recognises this construct and evaluates the collected
modules together when the value is used. Multiple files can now set
`flake.modules.nixos.hardware-z16 = ...` and the module system merges them.

**One-time type migration:** change `module-types.nix` first, before any
rename. Verify `nix flake check` passes with the type change alone (no renames
yet). This proves the existing unique-keyed modules are unaffected by the
type change — a single-definition deferred module is identical in behaviour
to a single `raw` value.

---

## 2. Step 0 — Type migration (one commit, no renames)

**File:** `modules/flake/module-types.nix`

Change both option type declarations:

```nix
# Before
type = lib.types.lazyAttrsOf lib.types.raw;

# After
type = lib.types.lazyAttrsOf lib.types.deferredModule;
```

Apply to both `flake.modules.nixos` and `flake.modules.homeManager`.

**Commit message:** `refactor(module-types): raw → deferredModule for merge semantics`

**Exit gate for Step 0:**
- `nix develop --command pre-commit run --files modules/flake/module-types.nix`
- `nix flake check`
- Regenerate all 6 host `.drv` paths. Every path must be **identical** to the
  baseline. A change here means the type swap has a semantic side-effect;
  stop and investigate before proceeding.

---

## 3. Merge groups — execution order and precise changes

Process one group per commit in the order below (ascending closure risk).

---

### Group 1: `development-default`

Simplest group. Pure aggregator with no config of its own.

**Target name:** `development-default`

**Files to rename (change registration key in each):**

| File | Old key | New key |
|---|---|---|
| `modules/programs/common.nix` | `flake.modules.nixos.programs-common` | `flake.modules.nixos.development-default` |
| `modules/programs/dev.nix` | `flake.modules.nixos.programs-dev` | `flake.modules.nixos.development-default` |
| `modules/programs/scripts.nix` | `flake.modules.nixos.programs-scripts` | `flake.modules.nixos.development-default` |

**File to delete:** `profiles/development/default.nix`
(Its only content is `imports = [programs-common programs-dev programs-scripts]`.
After merging those three into `development-default`, this file contributes nothing.)

**Caller changes:** None. `hosts/sweet16/default.nix` and `hosts/petunia/default.nix`
already import `nixosModules.development-default`. That name now resolves to
the merged deferred module.

**Verification:**
- No reference to `programs-common`, `programs-dev`, or `programs-scripts`
  should remain in the tree after this commit.
  ```bash
  grep -r 'programs-common\|programs-dev\|programs-scripts' \
    --include='*.nix' . && echo "FAIL: dangling refs" || echo "OK"
  ```
- `nix flake check` green.
- Regenerate `sweet16` and `petunia` `.drv`. Must match baseline.

**Commit message:** `refactor(modules): merge programs-{common,dev,scripts} → development-default`

---

### Group 2: `desktop-default` (hybrid aggregator)

This group is **hybrid**: `profiles/desktop/default.nix` both aggregates
and contributes `boot.kernelParams = ["quiet" "splash"]`. The file is **not
deleted**; the `imports` list inside it is removed and the kernel params
remain.

**Target name:** `desktop-default`

**Files to rename:**

| File | Old key | New key |
|---|---|---|
| `modules/desktop/greetd.nix` | `flake.modules.nixos.desktop-greetd` | `flake.modules.nixos.desktop-default` |
| `modules/desktop/wayland.nix` | `flake.modules.nixos.desktop-wayland` | `flake.modules.nixos.desktop-default` |
| `modules/desktop/fonts.nix` | `flake.modules.nixos.desktop-fonts` | `flake.modules.nixos.desktop-default` |
| `modules/desktop/theme.nix` | `flake.modules.nixos.desktop-theme` | `flake.modules.nixos.desktop-default` |

**File to modify (not delete):** `profiles/desktop/default.nix`

Before:
```nix
_: {
  flake.modules.nixos.desktop-default =
    { nixosModules, ... }:
    {
      imports = [
        nixosModules.desktop-greetd
        nixosModules.desktop-wayland
        nixosModules.desktop-fonts
        nixosModules.desktop-theme
      ];
      boot.kernelParams = [ "quiet" "splash" ];
    };
}
```

After (imports removed; kernel params remain as their own deferred contribution):
```nix
_: {
  flake.modules.nixos.desktop-default =
    { ... }:
    {
      boot.kernelParams = [ "quiet" "splash" ];
    };
}
```

The four renamed modules supply the content that was previously imported.
The deferred merge combines all five contributions (four renamed + the
remaining kernel-params file) into `desktop-default`.

**Caller changes:** None. `sweet16` and `petunia` already use `nixosModules.desktop-default`.

**Verification:**
- No reference to `desktop-greetd`, `desktop-wayland`, `desktop-fonts`,
  or `desktop-theme` remains.
  ```bash
  grep -r 'desktop-greetd\|desktop-wayland\|desktop-fonts\|desktop-theme' \
    --include='*.nix' . && echo "FAIL: dangling refs" || echo "OK"
  ```
- `nix flake check` green.
- Regenerate `sweet16` and `petunia` `.drv`. Must match baseline.

**Commit message:** `refactor(modules): merge desktop-{greetd,wayland,fonts,theme} → desktop-default`

---

### Group 3: `hardware-petunia` (two-level aggregation)

`hardware-petunia-default` is itself an aggregator that imports `rdna4` and
`ryzen`. `profiles/hardware/petunia.nix` then imports `hardware-petunia-default`
under the `hardware-petunia` name. Two levels collapse to zero.

**Target name:** `hardware-petunia`

**Files to rename:**

| File | Old key | New key |
|---|---|---|
| `modules/hardware/petunia/rdna4.nix` | `flake.modules.nixos.hardware-petunia-rdna4` | `flake.modules.nixos.hardware-petunia` |
| `modules/hardware/petunia/ryzen.nix` | `flake.modules.nixos.hardware-petunia-ryzen` | `flake.modules.nixos.hardware-petunia` |

**Files to delete:**
- `modules/hardware/petunia/default.nix` — registered `hardware-petunia-default`;
  its only purpose was to import `rdna4` and `ryzen`.
- `profiles/hardware/petunia.nix` — registered `hardware-petunia` by importing
  `hardware-petunia-default`. Redundant once the two leaves merge directly.

**Caller changes:** None. `hosts/petunia/default.nix` already uses
`nixosModules.hardware-petunia`. That name now resolves to the deferred merge.

**Verification:**
- No reference to `hardware-petunia-rdna4`, `hardware-petunia-ryzen`, or
  `hardware-petunia-default` remains.
  ```bash
  grep -r 'hardware-petunia-rdna4\|hardware-petunia-ryzen\|hardware-petunia-default' \
    --include='*.nix' . && echo "FAIL: dangling refs" || echo "OK"
  ```
- `nix flake check` green.
- Regenerate `petunia` `.drv`. Must match baseline.

**Commit message:** `refactor(modules): collapse hardware-petunia two-level aggregation → hardware-petunia`

---

### Group 4: `hardware-z16`

Single-level aggregation. Four leaf modules → one target name.

**Target name:** `hardware-z16`

**Files to rename:**

| File | Old key | New key |
|---|---|---|
| `modules/hardware/thinkpad-z16/amd-gpu.nix` | `flake.modules.nixos.hardware-z16-amd-gpu` | `flake.modules.nixos.hardware-z16` |
| `modules/hardware/thinkpad-z16/bluetooth.nix` | `flake.modules.nixos.hardware-z16-bluetooth` | `flake.modules.nixos.hardware-z16` |
| `modules/hardware/thinkpad-z16/sound.nix` | `flake.modules.nixos.hardware-z16-sound` | `flake.modules.nixos.hardware-z16` |
| `modules/hardware/thinkpad-z16/default.nix` | `flake.modules.nixos.hardware-z16-default` | `flake.modules.nixos.hardware-z16` |

**File to delete:** `profiles/hardware/z16.nix`
(Registered `hardware-z16` by importing the four leaves. The deferred merge
of the renamed files makes this aggregator unnecessary.)

**Caller changes:** None. `hosts/sweet16/default.nix` already uses
`nixosModules.hardware-z16`.

**Verification:**
- No reference to `hardware-z16-amd-gpu`, `hardware-z16-bluetooth`,
  `hardware-z16-sound`, or `hardware-z16-default` remains.
  ```bash
  grep -r 'hardware-z16-amd-gpu\|hardware-z16-bluetooth\|hardware-z16-sound\|hardware-z16-default' \
    --include='*.nix' . && echo "FAIL: dangling refs" || echo "OK"
  ```
- `nix flake check` green.
- Regenerate `sweet16` `.drv`. Must match baseline.

**Commit message:** `refactor(modules): merge hardware-z16-{amd-gpu,bluetooth,sound,default} → hardware-z16`

---

### Group 5: `services-matrix` (largest group)

Nine leaf modules → one target name. `services-matrix-whatsapp` is **not**
included — it was not part of the default aggregator and remains standalone.

**Target name:** `services-matrix`

**Files to rename:**

| File | Old key | New key |
|---|---|---|
| `modules/services/matrix/versions.nix` | `flake.modules.nixos.services-matrix-versions` | `flake.modules.nixos.services-matrix` |
| `modules/services/matrix/synapse.nix` | `flake.modules.nixos.services-matrix-synapse` | `flake.modules.nixos.services-matrix` |
| `modules/services/matrix/database.nix` | `flake.modules.nixos.services-matrix-database` | `flake.modules.nixos.services-matrix` |
| `modules/services/matrix/mas.nix` | `flake.modules.nixos.services-matrix-mas` | `flake.modules.nixos.services-matrix` |
| `modules/services/matrix/livekit.nix` | `flake.modules.nixos.services-matrix-livekit` | `flake.modules.nixos.services-matrix` |
| `modules/services/matrix/element.nix` | `flake.modules.nixos.services-matrix-element` | `flake.modules.nixos.services-matrix` |
| `modules/services/matrix/element-call.nix` | `flake.modules.nixos.services-matrix-element-call` | `flake.modules.nixos.services-matrix` |
| `modules/services/matrix/haproxy.nix` | `flake.modules.nixos.services-matrix-haproxy` | `flake.modules.nixos.services-matrix` |
| `modules/services/matrix/vault-secrets.nix` | `flake.modules.nixos.services-matrix-vault-secrets` | `flake.modules.nixos.services-matrix` |

**File to delete:** `modules/services/matrix/default.nix`
(Registered `services-matrix-default`; imports all 9 leaves listed above.)

**File NOT changed:** `modules/services/matrix/whatsapp.nix`
(`services-matrix-whatsapp` remains standalone — it is an optional bridge
not included in `services-matrix-default` and must stay independently selectable.)

**Caller changes:**

`hosts/avina/default.nix` imports `nixosModules.services-matrix-default`.
This must change to `nixosModules.services-matrix`.

Exact line to update:
```nix
# Before
nixosModules.services-matrix-default # Matrix 2.0 communications suite
# After
nixosModules.services-matrix # Matrix 2.0 communications suite
```

**Verification:**
- No reference to `services-matrix-default` or any `services-matrix-*`
  sub-name (except `services-matrix-whatsapp`) remains.
  ```bash
  grep -r 'services-matrix-default\|services-matrix-versions\|services-matrix-synapse\|services-matrix-database\|services-matrix-mas\|services-matrix-livekit\|services-matrix-element-call\|services-matrix-haproxy\|services-matrix-vault-secrets' \
    --include='*.nix' . && echo "FAIL: dangling refs" || echo "OK"
  # Note: services-matrix-element (without -call suffix) would also match services-matrix-element-call;
  # check the above output carefully. services-matrix-whatsapp must NOT appear in grep results.
  grep -r 'services-matrix-element[^-]' --include='*.nix' . && echo "FAIL" || echo "OK"
  ```
- `nix flake check` green.
- Regenerate `avina` `.drv`. Must match baseline.

**Commit message:** `refactor(modules): merge services-matrix-* (9 leaves) → services-matrix; keep whatsapp standalone`

---

## 4. Post-group verification (all groups complete)

After all five group commits:

```bash
# Confirm the full registry is clean — no sub-names survive
nix flake show --json 2>/dev/null \
  | nix-instantiate --eval --json -E 'builtins.fromJSON (builtins.readFile /dev/stdin)' \
    | jq '.[] | keys' 2>/dev/null || true

# Simpler: count total named nixos modules (should be lower than before)
grep -r 'flake\.modules\.nixos\.' --include='*.nix' -h . \
  | grep -oP 'flake\.modules\.nixos\.\K[a-z0-9_-]+' | sort -u
```

The output must contain **none** of the deleted sub-names and must still
contain all surviving target names.

---

## 5. Phase A exit criteria

- [ ] `module-types.nix` uses `lib.types.deferredModule` for both registries.
- [ ] All five aggregator files deleted (per §3 per-group tables); no replacements.
- [ ] All renamed modules pass `grep` clean-reference checks (no dangling refs).
- [ ] `avina` caller updated: `services-matrix-default` → `services-matrix`.
- [ ] `desktop-default` profile retains `boot.kernelParams`; `imports` block removed.
- [ ] `nix flake check` green; pre-commit green.
- [ ] All 6 NixOS host `.drv` paths identical to Phase A baseline or delta
      is explained and signed off in `.agents/SIGNOFF.md`.

Only when every box is checked: proceed to `.agents/phase-B.md`.
