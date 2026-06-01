# flake/AGENTS.md — Phase 1: Root Bootstrap (flake-parts + import-tree)

> **When to read this.** After the Gate B baseline is captured
> (`validation/AGENTS.md` §2), before any module conversion.
>
> **Goal of this phase.** Replace the hand-written `outputs` attrset with
> `flake-parts.lib.mkFlake` and wire `import-tree` so the rest of the tree can
> be converted file-by-file in later phases. This phase changes *only* the
> output-assembly mechanism. **No host's closure may change in Phase 1.**
>
> **Authorities.** `flake-parts` (`perSystem`, `mkFlake`, module args) and
> dendritic (`import-tree`, `flake.modules.*`). Fetch both (§0 root) before
> editing.

---

## 1. Preconditions

- [ ] `.refactor/baseline/*.drv` exists and is committed.
- [ ] You have read the current `flake.nix` in full this session.
- [ ] You have fetched the two §0 authority URLs this session.

If any box is unchecked, stop. Do not proceed on memory.

---

## 2. Input changes (exact, minimal)

Add two direct inputs. **Reuse the already-locked `flake-parts` node** — it is
present transitively in `flake.lock` (via `devenv`/`pre-commit-hooks`); promoting
it must not introduce a second, differently-locked copy.

```nix
# flake-parts: module system for flake outputs (§0 authority)
flake-parts.url = "github:hercules-ci/flake-parts";

# import-tree: recursive auto-discovery of every .nix file as a flake module
import-tree.url = "github:vic/import-tree";
```

**Do not touch** any other input. The `pkgs-*` pins, `nixpkgs-chrome`,
channel inputs, and all `follows` lines stay byte-for-byte as they are. After
editing, run `nix flake metadata` and confirm via `validation/AGENTS.md` §3
that no existing input re-locked.

---

## 3. The `mkFlake` skeleton

Replace the `outputs = { ... }: let ... in { ... }` body with the dendritic
entry point. The canonical mightyiam form delegates the entire output set to
`import-tree` over the repo root:

```nix
outputs = inputs:
  inputs.flake-parts.lib.mkFlake { inherit inputs; } (
    inputs.import-tree ./modules
  );
```

**Critical scoping decision — confirm against the dendritic authority before
committing.** mightyiam-strict points `import-tree` at a single directory that
contains *all* flake modules (commonly `./modules`). nix-nexus already has a
populated `modules/`, plus `hosts/` and `profiles/` trees. You must decide the
discovery root such that **every** `.nix` file intended as a flake module is
reachable, and nothing else (e.g. `hosts/*/hardware-configuration.nix`,
`disko.nix`, install scripts) is swept in prematurely. Options, in order of
fidelity to the authority:

1. **Single root (`import-tree ./modules`)** with `hosts/` and `profiles/`
   content *relocated under* `modules/` during Phases 2–3. Highest fidelity to
   mightyiam; largest move set.
2. **Multiple roots** (`import-tree` over a list including `./modules`,
   `./hosts`, `./profiles`). Lower move cost; verify the dendritic authority
   sanctions multi-root discovery before choosing it.

Record the choice and its authority citation in the Phase 1 report. Do not
default silently — this decision shapes Phases 2 and 3.

---

## 4. What moves into `perSystem` (behaviour-preserving)

The existing `checks`, `devShells`, and the `forAllSystems`/`systems` plumbing
are replaced by flake-parts' `systems` + `perSystem`. The **behaviour** must be
identical — same hooks, same shell.

Create the first flake module (this file *is* a dendritic module) to carry the
per-system surface. Example shape — validate every attribute path against the
flake-parts authority:

```nix
# modules/flake/checks.nix  (a flake-parts module: note the `perSystem`)
{ inputs, ... }:
{
  systems = [ "x86_64-linux" "aarch64-linux" ];

  perSystem = { system, pkgs, ... }: {
    checks.pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
      src = ../../.;
      hooks = {
        nixfmt-rfc-style.enable = true;
        deadnix.enable = true;
        statix.enable = true;
      };
    };

    devShells.default = pkgs.mkShell {
      inherit (config.checks.pre-commit-check) shellHook;   # wire via module `config`, not `self`
      buildInputs = config.checks.pre-commit-check.enabledPackages;
    };
  };
}
```

> **`self` → module-arg migration.** The old code referenced
> `self.checks.${system}.pre-commit-check`. Under flake-parts, intra-`perSystem`
> references use the `config` argument of `perSystem`, not `self`. Confirm the
> exact binding against the flake-parts authority; getting this wrong evaluates
> fine but can change the shell derivation — a Gate B failure.

---

## 5. Overlays in the dendritic world

`self.overlays.buildFixes` and `self.overlays.mcp` must become `flake.overlays.*`
contributions (a `flake` output, not `perSystem`). Move them into a flake module
(e.g. `modules/flake/overlays.nix`) that sets:

```nix
{ inputs, lib, ... }:
{
  flake.overlays.buildFixes = _: prev: { /* …unchanged body… */ };
  flake.overlays.mcp = lib.composeManyExtensions [
    # reference the sibling overlay via the flake output, not `self`
    inputs.self.overlays.buildFixes
    inputs.mcp-servers-nix.overlays.default
  ];
}
```

The overlay **bodies do not change** in Phase 1 — only their declaration site.
Any change to overlay *content* belongs to Phase 2/3 dedup work and must be
closure-diff justified. Note the `buildFixes` body imports `nixpkgs-unstable`
for the `mcp` python src; preserve that import verbatim.

---

## 6. Phase 1 exit criteria

- [ ] `outputs` is `flake-parts.lib.mkFlake` + `import-tree`.
- [ ] `flake-parts` and `import-tree` are direct inputs; **no other input
      re-locked** (verify via `validation/AGENTS.md` §3 pin check).
- [ ] `checks` and `devShells` reproduced under `perSystem`; `nix flake check`
      green and the pre-commit shell is functionally identical.
- [ ] Overlays exposed as `flake.overlays.{buildFixes,mcp}` with unchanged bodies.
- [ ] **Closure sentinel:** at least `sweet16` and `avina` (stable-channel,
      locally evaluable) produce **identical `.drv`** vs baseline. Hosts are not
      yet converted, so their toplevels still reference the old inline wiring —
      that is expected; the point is to prove the output-assembly swap alone
      introduced no drift. If `.drv` differs here, the `mkFlake` wiring changed
      something; do not advance to Phase 2 until it is identical or justified.
- [ ] Phase 1 report written: discovery-root choice + authority citation,
      `self`→`config`/`inputs.self` migration notes, pin-check result.

Only when every box is checked: proceed to `modules/AGENTS.md`.
