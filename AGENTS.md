# AGENTS.md — nix-nexus Dendritic Refactor Authority

> **Scope of this document set.** These files instruct an autonomous coding
> agent to refactor the `mister2d/nix-nexus` flake from its current
> **monolithic-flake** layout to the **dendritic pattern** built on
> `flake-parts`. This root file is the entry point. It states the invariants,
> the ground-truth starting state, and routes you to the nested `AGENTS.md`
> files that carry phase-specific instructions.
>
> **Progressive disclosure contract.** Do not load the whole set up front.
> Read this file, then read only the nested `AGENTS.md` for the subtree you are
> currently editing. Each nested file declares its own preconditions and exit
> criteria. The directory map is in [§5](#5-document-map).

---

## 0. Steering authorities (non-negotiable sources of truth)

This refactor is bound to two upstream references. When this document and the
upstream references disagree, **the upstream references win** and you must stop
and report the conflict rather than improvise.

| Authority | URL | Governs |
|---|---|---|
| Dendritic pattern | `https://github.com/mightyiam/dendritic` | File-as-module convention, `flake.modules.*` namespacing, `import-tree` auto-discovery |
| flake-parts | `https://github.com/hercules-ci/flake-parts` | Module system for flake outputs, `perSystem`, `mkFlake`, option declaration |

Use the `fetch` MCP tool to read these before Phase 1 and re-read the relevant
section before any phase that cites them. Do not rely on training-data memory
of either project; both move.

---

## 1. The two binding decision gates

These were set by the repository owner and are **not** open for the agent to
relax, reinterpret, or trade off for convenience.

### Gate A — Mightyiam-strict full dendritic

**Every `.nix` file in the tree becomes a `flake-parts` module.** No file
remains a "plain" NixOS/home-manager module imported by relative path. Leaf
configuration is contributed into the `flake.modules.nixos.<name>` and
`flake.modules.homeManager.<name>` namespaces; hosts collapse to thin
aggregations that reference those module **names**, not paths. There is no
"pragmatic subset" escape hatch. If a file resists conversion, stop and report
— do not leave it as a legacy import.

### Gate B — Closure-diff equivalence per host

The refactor must be **behaviour-preserving at the derivation level**. For all
6 NixOS hosts and 3 standalone home-manager configurations, the post-refactor
`config.system.build.toplevel` (NixOS) / `activationPackage` (HM) must produce
the **same store path** as the pre-refactor baseline, or — where a store-path
change is unavoidable and justified — a closure diff that contains **zero
unexplained additions or removals**. Functional-only equivalence
(`nix flake check` + dry-run) is **not** sufficient for merge. The closure-diff
procedure and its sign-off format are in `validation/AGENTS.md`.

---

## 2. Ground-truth starting state (verified against the committed tree)

Do not trust prose summaries — including the repo's existing root `AGENTS.md`,
which **inaccurately** claims the configuration is already "dendritic." It is
not. The following was verified directly against `flake.nix` and the file tree
at refactor start. Treat any deviation you observe as drift to investigate, not
as license to change the plan.

**Output assembly:** `outputs` is a hand-written attrset. `flake-parts` is
**not** a direct input and `mkFlake` is **not** used. (Note: `flake-parts` and
`flake-utils` already appear in `flake.lock` as *transitive* deps of `devenv`
and `pre-commit-hooks`; promoting `flake-parts` to a direct input is required
and must reuse — not fork — the locked node where possible.)

**Hosts (6 NixOS):**

| Host | Channel | Builder | Notable inline injection |
|---|---|---|---|
| `sweet16` | `nixpkgs` (25.11) | `nixpkgs.lib.nixosSystem` | nixos-hardware z16 stack, HM block |
| `petunia` | **`nixpkgs-unstable`** | `inputs.nixpkgs-unstable.lib.nixosSystem` | disko, rdna4-stack, `home-manager-unstable` |
| `avina` | `nixpkgs` (25.11) | `nixpkgs.lib.nixosSystem` | inline Matrix-stack `pkgs-stable` overlay |
| `openclaw` | `nixpkgs` (25.11) | `nixpkgs.lib.nixosSystem` | inline `groot` HM block (no `home.nix` module reuse pattern) |
| `hermes` | `nixpkgs` (25.11) | `nixpkgs.lib.nixosSystem` | inline `llm-agents` + `mcp` overlays, inline `unstablePkgs` |

**Standalone HM (3):** `groot@dualie`, `groot@rk3588` (aarch64), `groot@forge`,
each via `home-manager.lib.homeManagerConfiguration`.

**Cross-cutting concerns currently inlined per host (the primary refactor
targets):**
- `buildFixes` overlay + `nixpkgs.config.allowUnfree = true` setter (repeated in
  every host; also redundantly set in `profiles/server` and
  `profiles/workstation` — reconcile, do not duplicate).
- The full `home-manager.nixosModules.home-manager` wiring block (repeated, with
  per-host divergence between `ddukes` and `groot` users).
- Host-specific overlays: avina's Matrix pinning, hermes's `llm-agents`/MCP.

**Overlays exposed today:** `self.overlays.buildFixes` and `self.overlays.mcp`
(`mcp = composeManyExtensions [ buildFixes mcp-servers-nix.default ]`). The
spelling `self.buildFixesOverlay` appears in a stale *plan doc* only and is
**not** in the committed flake — ignore it.

**`specialArgs` consumers:** `self` is read by `modules/programs/dev.nix`,
`modules/programs/custom-scripts.nix`, `modules/user/dev-home.nix`, and three
Matrix modules (`haproxy.nix`, `synapse.nix`, `element.nix`). `inputs` is read
broadly. **Migration hazard:** in the dendritic pattern these arrive via the
flake-parts module arg (`{ inputs, ... }`, with `inputs.self`), not
`specialArgs`. Preserving access for these six modules is a Phase-3 gate.

**Pinned inputs that must survive untouched:** `pkgs-nomad`, `pkgs-hashicorp`,
`pkgs-terraform`, `pkgs-talos`, `pkgs-vlc`, `pkgs-apps`, `pkgs-ceph`,
`pkgs-stable`, `nixpkgs-chrome`. These are commit-pinned for reproducibility;
the refactor relocates *how they are referenced*, never *what they resolve to*.

**CI surface to preserve:** `checks.<system>.pre-commit-check`
(nixfmt-rfc-style, deadnix, statix) and `devShells.<system>.default`. These move
into flake-parts `perSystem`; their behaviour must not change.

---

## 3. Universal operating rules (apply in every phase)

1. **Work from actual source files.** Before editing any file, read it. Before
   asserting tree structure, list it. Never generate a module from an assumed
   shape. If you have not opened a file in this session, you do not know its
   contents.
2. **One phase per branch, one host per commit where applicable.** Never refactor
   two hosts in a single commit — closure-diff sign-off (Gate B) is per host.
3. **Baseline before you touch anything.** The first action of the whole effort
   is capturing the pre-refactor closure baseline (see `validation/AGENTS.md`).
   Without a baseline, Gate B is unverifiable and the work is invalid.
4. **No store-path drift without a written explanation.** Any closure delta gets
   a one-line justification in the phase report. "It changed" is not a
   justification.
5. **Lint and eval gate every commit.** Run, in order:
   `nix develop --command pre-commit run --files <changed>` then
   `nix flake check`. A commit that fails either does not exist.
6. **Honest uncertainty over false confidence.** If you cannot determine whether
   a conversion is behaviour-preserving, say so and stop. A blocked phase
   reported accurately is worth more than a merged phase that silently drifts.
7. **Do not invent dendritic idioms.** Every structural choice must trace to the
   §0 authorities. If the authorities are silent on a case, surface it as an
   open question — do not fill the gap from memory.

---

## 4. MCP tool protocol (inherited from the existing root AGENTS.md, preserved)

You have five MCP servers: `context7`, `nixos-tools` (exposes the unified `nix`
tool), `time`, `git`, `fetch`. Before generating or modifying `.nix` code:

1. **Plan** — decompose the task before writing code.
2. **Context** (`git`, `fetch`) — review working tree / diffs; `fetch` the §0
   authority URLs and any user-supplied URL.
3. **Knowledge** (`time`, `context7`, `nixos-tools`) — anchor releases with
   `time`; `nix(source="wiki"|"nix-dev")` for official docs; `context7` for
   external-framework patterns (here: `flake-parts`, `import-tree`).
4. **Validate** (`nixos-tools`) —
   `nix(action="search", source="nixos", type="packages")` to confirm packages;
   `nix(action="search", source="home-manager"|"nixos")` to confirm options;
   `nix_versions` for pinned commits; `nix(action="flake-inputs", type="list")`
   to enumerate inputs.
5. **Narrative docs.** Generated comments and docs read as the project's
   coherent design story, never as an iterative changelog.

---

## 5. Document map

Load nested files lazily — only the one for the subtree you are in.

```
AGENTS.md                      ← you are here (invariants + routing)
├── flake/AGENTS.md            ← Phase 1: bootstrap flake-parts + import-tree at the root
├── modules/AGENTS.md          ← Phase 2: convert leaf modules to flake.modules.* contributors
├── hosts/AGENTS.md            ← Phase 3: collapse hosts to module-name aggregations
└── validation/AGENTS.md       ← Gate B: closure-diff baseline + per-host sign-off (run continuously)
```

**Execution order:** `validation` baseline → `flake` → `modules` → `hosts` →
`validation` sign-off per host. Validation is not a final step; it brackets the
work. Read `validation/AGENTS.md` first to capture the baseline, then return
here and proceed to `flake/AGENTS.md`.

---

## 6. Definition of done

- [ ] `flake.nix` uses `flake-parts.lib.mkFlake` with `import-tree` discovery.
- [ ] Zero `.nix` files remain as path-imported legacy modules (Gate A).
- [ ] All 6 NixOS hosts + 3 HM configs pass per-host closure-diff sign-off
      (Gate B) with every delta explained.
- [ ] `checks` and `devShells` behaviour preserved under `perSystem`.
- [ ] All pinned `pkgs-*` inputs resolve to identical commits post-refactor.
- [ ] `nix flake check` green; pre-commit (nixfmt-rfc-style/deadnix/statix) green.
- [ ] The inaccurate "dendritic" claim in the old root prose is now *true*.
