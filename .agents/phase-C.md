# .agents/phase-C.md — Import-Tree Composable Builder

> **Precondition:** Phase B exit criteria are met. `nix flake check` is green.
>
> **Goal.** Replace the three separate `import-tree` roots in `flake.nix`
> with a single composable builder using `addPath` chaining and `.result`.
> This change has zero behavioural effect — it is a structural simplification
> of the discovery pipeline.
>
> **Authority.** import-tree README (`addPath`, `result`) and advanced topics
> (`addAPI`, composition patterns). Re-fetch the README before editing.

---

## 1. Why the three-root pattern is suboptimal

The current outputs block in `flake.nix`:

```nix
outputs =
  inputs:
  inputs.flake-parts.lib.mkFlake { inherit inputs; } (_: {
    imports = [
      (inputs.import-tree ./modules)
      (inputs.import-tree ./hosts)
      (inputs.import-tree ./profiles)
    ];
  });
```

Three separate `import-tree` invocations means:

- **No shared configuration.** Filters, `matchNot` patterns, and `addAPI`
  extensions must be applied individually to each root, or not at all.
- **Edit surface on growth.** Adding a fourth subtree (e.g., `./lib`) requires
  editing the `imports` list in `flake.nix`.
- **Not composable.** Three independent roots cannot be narrowed into a single
  domain-specific pipeline without restructuring.

The import-tree composable builder API addresses all three points.

---

## 2. The target pattern

The import-tree `addPath` method returns a new import-tree object with the
path appended to its discovery set. `builtins.foldl'` applies this cleanly
over a list of subtree roots.

```nix
outputs =
  inputs:
  let
    # Fleet-wide import tree.
    # Add future subtrees by appending a path to the list — no other changes.
    fleet = builtins.foldl' (it: p: it.addPath p) inputs.import-tree [
      ./modules
      ./hosts
      ./profiles
    ];
  in
  inputs.flake-parts.lib.mkFlake { inherit inputs; } fleet.result;
```

**`fleet.result`** is documented as equivalent to `fleet []` — it produces a
flake-parts module (an attrset `{ imports = [ ...all-discovered-files... ]; }`)
suitable as the second argument to `mkFlake`. The quick-start example
`(inputs.import-tree ./modules)` demonstrates that an import-tree call result
is a valid `mkFlake` module; `.result` on a pre-configured object is
structurally identical.

**`builtins.foldl'`** is a Nix built-in; no library import is required. The
strict variant (`foldl'`) is preferred to avoid thunk accumulation on long
lists.

---

## 3. Optional: `addAPI` for role-based selection

If the fleet grows and callers need to select subsets of the tree (e.g.,
"only module-type files" or "only host files"), `addAPI` makes this first-class
without editing `flake.nix`. This is an **optional enhancement** for this
phase; implement it if the team anticipates needing subset selection.

```nix
fleet = (builtins.foldl' (it: p: it.addPath p) inputs.import-tree [
  ./modules
  ./hosts
  ./profiles
]).addAPI {
  # Role-based selectors — enables downstream callers like:
  # fleet.nixosModules    for discovering only NixOS module files
  # fleet.hostConfigs     for discovering only host assemblies
  modules  = self: self.match ".*/modules/[^/]+\\.nix";
  hosts    = self: self.match ".*/hosts/[^/]+/[^/]+\\.nix";
  profiles = self: self.match ".*/profiles/[^/]+\\.nix";
};
```

If `addAPI` is added, `fleet.result` still returns all paths (unchanged).
The new methods are opt-in filters for future use.

**Decision gate:** Do not add `addAPI` if there is no immediate consumer of
the role-based selectors. Premature API surface is its own form of clutter.

---

## 4. Global `matchNot` — apply uniformly or not at all

The composable builder makes it straightforward to apply a global exclusion
pattern to every discovered path. The current tree does not require this —
all `.nix` files are valid dendritic modules or are correctly wrapped. However,
if non-module `.nix` files are introduced in the future (e.g., pure library
helpers under `./lib` that should not be imported as modules), a global
`matchNot` is the correct mechanism:

```nix
fleet = (builtins.foldl' (it: p: it.addPath p) inputs.import-tree [
  ./modules
  ./hosts
  ./profiles
]).matchNot ".*/lib/[^/]+\\.nix";  # exclude pure library files from module discovery
```

**For this phase:** Do not add a `matchNot` unless there is a concrete file
that needs to be excluded. The default import-tree filter (`.nix` suffix,
no `/_` infix) is sufficient for the current tree.

---

## 5. Exact diff for `flake.nix`

**Only the `outputs` attribute changes.** All inputs, the description, and the
`flake-parts` / `import-tree` input declarations are untouched.

```diff
-  outputs =
-    inputs:
-    inputs.flake-parts.lib.mkFlake { inherit inputs; } (_: {
-      imports = [
-        (inputs.import-tree ./modules)
-        (inputs.import-tree ./hosts)
-        (inputs.import-tree ./profiles)
-      ];
-    });
+  outputs =
+    inputs:
+    let
+      # Fleet-wide import tree.
+      # Add future subtrees by appending a path to this list only.
+      fleet = builtins.foldl' (it: p: it.addPath p) inputs.import-tree [
+        ./modules
+        ./hosts
+        ./profiles
+      ];
+    in
+    inputs.flake-parts.lib.mkFlake { inherit inputs; } fleet.result;
```

---

## 6. Commit procedure

```bash
# Edit only flake.nix
git add flake.nix

# Lint (nixfmt-rfc-style formats flake.nix; statix checks for anti-patterns)
nix develop --command pre-commit run --files flake.nix

# Evaluate — this is the primary correctness gate
nix flake check

# Confirm flake outputs are structurally identical to pre-Phase-C
nix flake show
```

**Commit message:** `refactor(flake): replace 3-root import-tree with composable addPath builder`

---

## 7. Closure verification

Because this change only restructures how import-tree discovers files
(same files, same order within each subtree, same module content), all
host derivations must be **identical** to the Phase B baseline.

```bash
# Spot-check sweet16 and avina (one workstation, one server)
for host in sweet16 avina; do
  echo -n "$host: "
  nix derivation show ".#nixosConfigurations.$host.config.system.build.toplevel" \
    | sha256sum
done
# Compare both hashes against Phase B entries in .agents/SIGNOFF.md
```

If any hash differs: the builder change has altered file discovery order or
included/excluded a file that the three-root pattern did not. Investigate with:

```bash
# List all files discovered by the new builder
nix-instantiate --eval -E '
  let
    inputs = (builtins.getFlake (toString ./.)).inputs;
    fleet = builtins.foldl'"'"' (it: p: it.addPath p) inputs.import-tree
      [ ./modules ./hosts ./profiles ];
  in
    fleet.withLib (import <nixpkgs> {}).lib |> (f: f.files)
' 2>/dev/null
```

Compare against the three-root discovery list to identify any discrepancy.

---

## 8. Phase C exit criteria

- [ ] `flake.nix` `outputs` block replaced with `builtins.foldl'` composable builder.
- [ ] No other changes to `flake.nix` (inputs, description unchanged).
- [ ] `nix flake check` green; `nix flake show` structurally identical to pre-phase.
- [ ] Pre-commit (nixfmt-rfc-style, deadnix, statix) green on `flake.nix`.
- [ ] All 6 host `.drv` hashes identical to Phase B sign-off.
- [ ] Phase C sign-off entry appended to `.agents/SIGNOFF.md`.

When every box is checked, return to root `AGENTS.md` §6 Definition of Done
and verify the full set. The simplification refactor is complete.
