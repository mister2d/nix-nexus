# .agents/phase-B.md — Option Namespace Tightening

> **Precondition:** Phase A exit criteria are met. `nix flake check` is green.
> `.agents/SIGNOFF.md` has passing Phase A entries for all 6 hosts.
>
> **Goal.** Rename the `nix-nexus.tailscale.*` option path to
> `nix-nexus.networking.tailscale.*` in its declaration and in every caller.
> This is a single atomic commit: declaration change + all caller updates land
> together so the tree is never in a broken intermediate state.
>
> **Authority.** flake-parts manual: *"most modules will put all their options
> inside a namespace named after their module instead."* The module responsible
> for `networking` configuration is `core-networking`; its options belong under
> `nix-nexus.networking.*`.

---

## 1. Why this rename and nothing else

Only one option path violates the module-scoped namespace rule (verified from
the committed tree):

| Declaration file | Current path | Status |
|---|---|---|
| `modules/core/networking.nix` | `nix-nexus.tailscale.homeSSIDs` | **Non-conforming** — `tailscale` is not a top-level subsystem name |
| `modules/core/zfs.nix` | `nix-nexus.zfs.*` | Conforming — `zfs` names the subsystem correctly |

`nix-nexus.tailscale.*` violates the rule because `tailscale` is a service
managed by the `networking` module, not an independent top-level subsystem.
The correct path is `nix-nexus.networking.tailscale.*`.

Do not rename `nix-nexus.zfs.*` — it is already correct.

---

## 2. Complete change set (one commit)

### 2a. Declaration — `modules/core/networking.nix`

Locate the options block:

```nix
options.nix-nexus.tailscale = {
  homeSSIDs = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''...'';
  };
};
```

Change to:

```nix
options.nix-nexus.networking.tailscale = {
  homeSSIDs = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''...'';
  };
};
```

Locate the `cfg` binding in the same file:

```nix
let
  cfg = config.nix-nexus.tailscale;
in
```

Change to:

```nix
let
  cfg = config.nix-nexus.networking.tailscale;
in
```

No other changes are needed in this file — `cfg` references throughout the
module body remain valid.

### 2b. Caller — `hosts/sweet16/default.nix`

Locate the assignment:

```nix
nix-nexus.tailscale.homeSSIDs = [
  "Trial"
];
```

Change to:

```nix
nix-nexus.networking.tailscale.homeSSIDs = [
  "Trial"
];
```

---

## 3. Exhaustive caller audit (mandatory before commit)

Before committing, verify there are no other callers of the old path in the
tree. This is a hard requirement — an unconverted caller causes a build failure.

```bash
# Must return zero matches after the changes
grep -rn 'nix-nexus\.tailscale' --include='*.nix' . \
  && echo "FAIL: stale references found" \
  || echo "OK: no stale nix-nexus.tailscale references"
```

If any match is found, convert it before committing.

Also verify the new path is present in exactly the expected files:

```bash
grep -rn 'nix-nexus\.networking\.tailscale' --include='*.nix' .
# Expected output: two lines only —
#   modules/core/networking.nix (declaration, × 2: options + cfg binding)
#   hosts/sweet16/default.nix (caller, × 1: homeSSIDs assignment)
```

---

## 4. Commit procedure

```bash
# Stage the two changed files
git add modules/core/networking.nix hosts/sweet16/default.nix

# Lint
nix develop --command pre-commit run --files \
  modules/core/networking.nix hosts/sweet16/default.nix

# Evaluate
nix flake check
```

**Commit message:** `refactor(options): nix-nexus.tailscale → nix-nexus.networking.tailscale`

---

## 5. Closure verification

This rename is a pure option path change. The evaluated NixOS configuration
for `sweet16` must produce an **identical** store derivation — the rename
affects only the Nix module system's internal option attrset, not the rendered
systemd units or scripts.

```bash
# Regenerate sweet16 drv and diff against Phase A (not Phase 0 — Phase A is now the baseline)
nix derivation show .#nixosConfigurations.sweet16.config.system.build.toplevel \
  | sha256sum
# Compare to Phase A sign-off hash in .agents/SIGNOFF.md
```

If the hash differs: the option rename has leaked into rendered output
(e.g., a script that interpolates the option path as a string). Investigate
and fix before signing off.

---

## 6. Phase B exit criteria

- [ ] `options.nix-nexus.tailscale` renamed to `options.nix-nexus.networking.tailscale`
      in `modules/core/networking.nix`.
- [ ] `cfg = config.nix-nexus.tailscale` updated to `config.nix-nexus.networking.tailscale`
      in the same file.
- [ ] `nix-nexus.tailscale.homeSSIDs` caller in `hosts/sweet16/default.nix` updated.
- [ ] `grep -rn 'nix-nexus\.tailscale'` returns zero matches.
- [ ] `nix flake check` green; pre-commit green.
- [ ] `sweet16` `.drv` hash identical to Phase A sign-off.
- [ ] Phase B sign-off entry appended to `.agents/SIGNOFF.md`.

Only when every box is checked: proceed to `.agents/phase-C.md`.
