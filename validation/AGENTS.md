# validation/AGENTS.md — Gate B: Closure-Diff Equivalence

> **When to read this.** First (to capture the baseline before any edit) and
> again before every host merge. Validation brackets the refactor; it is not a
> final step.
>
> **Authority.** Gate B in the root `AGENTS.md`: every host and HM config must
> build to the same store path as its pre-refactor baseline, or to a closure
> whose every delta is explained. Functional equivalence is insufficient.

---

## 1. Why store-path equivalence, not just `nix flake check`

`nix flake check` proves the tree *evaluates* and passes hooks. It does **not**
prove the system you ship is unchanged. The dendritic refactor relocates how
modules and overlays are wired; a subtle reordering of overlays, a dropped
`allowUnfree`, or `self`/`inputs` arriving by a different path can silently
alter a derivation while still evaluating clean. The store path is the only
witness that the *built system* is identical. That is the contract.

---

## 2. Baseline capture (run once, before touching anything)

Do this on the **pre-refactor** commit. Tag it so it is recoverable.

```bash
git rev-parse HEAD > .refactor-baseline-rev
git tag refactor-baseline
```

For each NixOS host, evaluate the toplevel store path **without building**
(`--no-link`, `--eval-store` to avoid realising the closure):

```bash
mkdir -p .refactor/baseline
for h in sweet16 petunia avina openclaw hermes; do
  nix path-info --derivation \
    ".#nixosConfigurations.$h.config.system.build.toplevel" \
    > ".refactor/baseline/$h.drv" 2>".refactor/baseline/$h.err" \
    || echo "EVAL-FAIL $h (record the error; some hosts only eval on their own arch)"
done
```

For the 3 standalone HM configs:

```bash
for c in "groot@dualie" "groot@rk3588" "groot@forge"; do
  safe="${c/@/_at_}"
  nix path-info --derivation \
    ".#homeConfigurations.\"$c\".activationPackage" \
    > ".refactor/baseline/$safe.drv" 2>".refactor/baseline/$safe.err" \
    || echo "EVAL-FAIL $c"
done
```

**`.drv` path, not output path.** Compare derivation paths. The `.drv` hash is
the input-addressed fingerprint of *everything* that goes into the build — it
changes if any input, arg, or overlay order changes, which is exactly the drift
Gate B exists to catch. Two identical `.drv` paths guarantee identical output.

**Arch caveat.** `petunia` (unstable channel) and `rk3588` (aarch64) may not
evaluate fully on every builder. If an arch/channel prevents local eval, record
the `EVAL-FAIL` and defer that host's sign-off to a builder that can evaluate
it; do **not** mark it equivalent on faith.

Commit the baseline:

```bash
git add .refactor/baseline && git commit -m "chore: capture pre-refactor closure baseline (Gate B)"
```

---

## 3. Per-host sign-off (run before each host merge)

After a host is converted (Phase 3), regenerate its `.drv` and diff:

```bash
h=sweet16   # the host under sign-off
nix path-info --derivation \
  ".#nixosConfigurations.$h.config.system.build.toplevel" \
  > ".refactor/candidate-$h.drv"

diff ".refactor/baseline/$h.drv" ".refactor/candidate-$h.drv" && echo "IDENTICAL .drv — PASS"
```

If the `.drv` paths differ, the change is **not** automatically a failure, but
it **is** automatically a stop. Produce the closure diff and account for every
line:

```bash
# Build both toplevels (baseline from the tag, candidate from HEAD), then:
nix store diff-closures /nix/store/<baseline-out> /nix/store/<candidate-out>
```

Every added, removed, or version-changed path must map to a **deliberate**
refactor action. The allowable causes are narrow:

| Delta | Allowed? | Required justification |
|---|---|---|
| No delta (identical `.drv`) | ✅ | none |
| Overlay applied in a new but equivalent order, same result | ⚠️ | prove output identical; prefer preserving original order |
| Path added/removed | ❌ default | must trace to an intentional dedup (e.g. removing a redundant `allowUnfree`) with proof it is a no-op |
| Version change of any package | ❌ | a refactor must never bump a version; investigate input drift |

**`pkgs-*` pin check (every host).** Confirm the pinned inputs still resolve to
the recorded commits — a relocated reference that silently re-locks is a Gate B
failure:

```bash
nix flake metadata --json | jq -r '
  .locks.nodes | to_entries[]
  | select(.key|test("^pkgs-|^nixpkgs-chrome$"))
  | "\(.key)\t\(.value.locked.rev)"'
```

Diff this against the same query on `refactor-baseline`. Any rev change blocks
sign-off.

---

## 4. Sign-off record format

Append one block per host to `.refactor/SIGNOFF.md`. No host merges without it.

```markdown
### <host> — <PASS|PASS-WITH-DELTA|BLOCKED>
- baseline .drv: <hash>
- candidate .drv: <hash>
- closure diff: <"identical" | N additions / M removals / K version-changes>
- justification: <one line per delta; "n/a" if identical>
- pkgs-* pins: <"unchanged" | list of changed revs — BLOCKS if any>
- nix flake check: <green|red>
- pre-commit: <green|red>
- signed: <agent-run-id> <UTC timestamp>
```

`PASS-WITH-DELTA` is only valid when every delta row has a non-trivial
justification proving behavioural equivalence. When in doubt, mark `BLOCKED`
and report up — never round a delta down to a pass.

---

## 5. Exit criterion

Gate B is satisfied only when `.refactor/SIGNOFF.md` contains a `PASS` or a
fully-justified `PASS-WITH-DELTA` for **all 6 NixOS hosts and all 3 HM
configs**, and the `pkgs-*` pin check is `unchanged` across the board.