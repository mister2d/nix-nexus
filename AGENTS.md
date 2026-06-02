# AGENTS.md — nix-nexus Simplification Refactor Authority

> **Supersedes:** The previous root AGENTS.md (dendritic refactor). That work
> is complete. The tree is now fully dendritic per Gate A of the prior effort.
> This document governs the next architectural pass: tightening what the
> dendritic pattern enables but the first refactor left underutilised.
>
> **Progressive disclosure contract.** Read this file first. Then read only
> the `.agents/` document for the phase you are actively executing. Each phase
> document is self-contained with its own preconditions and exit criteria.
> Do not load the whole set at once.

---

## 0. Steering authorities

When this document and an upstream reference conflict, **the upstream
reference wins**. Stop and report the conflict; do not improvise.

| Authority | URL | Governs |
|---|---|---|
| Dendritic pattern | `https://github.com/mightyiam/dendritic` | `flake.modules.*` namespace, deferred module merge semantics |
| flake-parts | `https://github.com/hercules-ci/flake-parts` | Option namespacing rules, `perSystem`, module system |
| import-tree README | `https://github.com/vic/import-tree` (README + `default.nix`) | Builder API: `addPath`, `filter`, `matchNot`, `addAPI`, `result` |
| import-tree advanced | `https://deepwiki.com/vic/import-tree/5-advanced-topics` | Composition patterns, `addAPI`, pipeline integration |

Use the `fetch` MCP tool to re-read relevant sections before each phase.
Do not rely on training-data memory of any of these projects.

---

## 1. Ground-truth starting state (verified against committed tree)

The following was verified by direct inspection of the committed tree.
Any deviation from this description is **drift to investigate**, not license
to change the plan.

### 1a. Flake structure

`flake.nix` uses `flake-parts.lib.mkFlake` with three separate `import-tree`
roots hardcoded in the outputs block:

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

### 1b. Module type definitions (`modules/flake/module-types.nix`)

Both registries use `lib.types.raw`, which **does not merge** — a duplicate
attribute key across two modules raises an evaluation conflict:

```nix
flake.modules.nixos      = lib.mkOption { type = lib.types.lazyAttrsOf lib.types.raw; ... };
flake.modules.homeManager = lib.mkOption { type = lib.types.lazyAttrsOf lib.types.raw; ... };
```

### 1c. Named modules and their aggregation pattern (verified)

The following groups each consist of granular named modules that have **no
independent callers** — they are only ever imported by a single aggregator
module. This is the anti-pattern to eliminate.

| Group target name | Current leaf names | Aggregator to delete |
|---|---|---|
| `hardware-z16` | `hardware-z16-amd-gpu`, `hardware-z16-bluetooth`, `hardware-z16-sound`, `hardware-z16-default` | `profiles/hardware/z16.nix` |
| `hardware-petunia` | `hardware-petunia-rdna4`, `hardware-petunia-ryzen` (+ intermediate `hardware-petunia-default`) | `modules/hardware/petunia/default.nix` + `profiles/hardware/petunia.nix` (two-level) |
| `services-matrix` | `services-matrix-versions`, `services-matrix-synapse`, `services-matrix-database`, `services-matrix-mas`, `services-matrix-livekit`, `services-matrix-element`, `services-matrix-element-call`, `services-matrix-haproxy`, `services-matrix-vault-secrets` | `modules/services/matrix/default.nix` |
| `desktop-default` | `desktop-greetd`, `desktop-wayland`, `desktop-fonts`, `desktop-theme` | `profiles/desktop/default.nix` — **hybrid**: also sets `boot.kernelParams`; the file stays, only the `imports` list is removed |
| `development-default` | `programs-common`, `programs-dev`, `programs-scripts` | `profiles/development/default.nix` |

**Not candidates for merging** (independent callers or mutually exclusive choices):

- `core-{boot,networking,security,sysctl,users,zfs}` — `workstation-default`
  and `server-default` import different subsets; cannot collapse.
- `desktop-{sway,niri,dank-material-shell}` — optional compositors;
  mutually exclusive per host.
- `services-matrix-whatsapp` — optional bridge, absent from the default
  aggregator; keep standalone.
- All `hardware-z16-*-home` HM variants — compositor-specific; mutually
  exclusive. Do not merge.

### 1d. Custom option namespaces (verified)

Two modules declare custom options under `nix-nexus.*`:

| Module file | Current path | Problem | Caller |
|---|---|---|---|
| `modules/core/networking.nix` | `nix-nexus.tailscale.homeSSIDs` | Overly flat: `tailscale` is not `core-networking` | `hosts/sweet16/default.nix` |
| `modules/core/zfs.nix` | `nix-nexus.zfs.*` | Correct: `zfs` names the subsystem | `hosts/sweet16/default.nix`, `hosts/petunia/default.nix` |

The flake-parts manual: *"most modules will put all their options inside a
namespace named after their module."* `nix-nexus.tailscale.*` must become
`nix-nexus.networking.tailscale.*`.

### 1e. Host module references (verified — these drive caller change tracking)

| Host | References `nixosModules.*` as | Changes in Phase A |
|---|---|---|
| `sweet16` | `hardware-z16`, `workstation-default`, `desktop-default`, `development-default`, `desktop-sway` | none — already uses target names |
| `petunia` | `hardware-petunia`, `workstation-default`, `desktop-default`, `development-default`, `desktop-sway` | none — already uses target names |
| `avina` | `server-default`, `services-matrix-default` | `services-matrix-default` → `services-matrix` |
| `hermes` | `server-default` | none |
| `openclaw` | `server-default`, `openclaw-vault-secrets` | none |

---

## 2. The three binding goals

### Goal A — Eliminate named-module proliferation via deferred module merge

`lib.types.deferredModule` merges multiple definitions of the same attribute
name using the module system's merge semantics (`{ _type = "merge"; contents = [...]; }`).
Switching both registries from `raw` to `deferredModule` makes aggregators
unnecessary: each sub-module file contributes directly to the shared target name.

**Invariant:** After Phase A, the five aggregator files identified in §1c are
deleted. No new aggregator files replace them.

### Goal B — Tighten option namespaces to module-scoped paths

`nix-nexus.tailscale.*` → `nix-nexus.networking.tailscale.*`. The declaration
and all callers change atomically in one commit.

**Invariant:** After Phase B, zero custom `nix-nexus` options sit at a path
depth shallower than `nix-nexus.<subsystem>.*`.

### Goal C — Replace three-root import-tree with a composable builder

`flake.nix` replaces three separate `import-tree` calls with one composable
builder using `addPath` chaining and `result`. Future subtrees require only
a new `addPath`; `flake.nix` is not otherwise edited.

**Invariant:** After Phase C, `flake.nix` contains exactly one import-tree
evaluation expression. The three-root list is gone.

---

## 3. Universal operating rules (every phase)

1. **Work from actual source files.** Read before editing. List before
   asserting structure. If you have not opened a file in this session, you do
   not know its contents.
2. **Baseline before touch.** First action of each phase: capture the
   pre-phase closure baseline per `.agents/validation.md`. Without a baseline
   Gate B (closure equivalence) is unverifiable.
3. **One group per commit.** Do not batch multiple merge groups or phases.
   Closure-diff sign-off is per commit.
4. **No store-path drift without explanation.** Every closure delta needs a
   one-line written justification. "It changed" is not a justification.
5. **Lint and eval every commit.**
   `nix develop --command pre-commit run --files <changed>` then
   `nix flake check`. Neither may fail.
6. **Honest uncertainty.** If you cannot confirm behaviour-preserving status,
   stop and report. A blocked phase accurately described is better than a
   silently drifted merge.
7. **No invented patterns.** Every structural choice traces to §0 authorities.
   Gaps are open questions, not licence to fill from memory.

---

## 4. MCP tool protocol

Five servers available: `context7`, `nixos-tools`, `time`, `git`, `fetch`.

1. **Plan** — decompose before writing any code.
2. **Context** (`git`, `fetch`) — review diffs; `fetch` §0 authority URLs.
3. **Knowledge** (`nixos-tools`) — verify `lib.types.deferredModule` merge
   semantics before Phase A; check option type APIs.
4. **Validate** — `nix flake check` after every commit.

---

## 5. Document map

Load only the document for the phase you are actively executing.

```
AGENTS.md                          ← you are here
└── .agents/
    ├── validation.md              ← FIRST and continuous: baseline + sign-off
    ├── phase-A.md                 ← deferred module merge
    ├── phase-B.md                 ← option namespace tightening
    └── phase-C.md                 ← import-tree composable builder
```

**Execution order:**
1. `.agents/validation.md` — baseline capture before any edit.
2. `.agents/phase-A.md` — largest change set; highest closure risk; first.
3. `.agents/phase-B.md` — rename + caller update; atomic.
4. `.agents/phase-C.md` — structural only; no behavioral change.
5. `.agents/validation.md` — final sign-off across all hosts.

---

## 6. Definition of done

- [ ] `module-types.nix` uses `lib.types.deferredModule` for both registries.
- [ ] All five aggregator files (§1c) deleted; no replacements introduced.
- [ ] All sub-modules renamed to their shared target name; zero dangling references.
- [ ] `nix-nexus.tailscale.*` → `nix-nexus.networking.tailscale.*` everywhere.
- [ ] `flake.nix` contains one composable builder; three-root pattern is gone.
- [ ] `.agents/SIGNOFF.md` holds a passing block for all 6 NixOS hosts and
      3 standalone HM configs.
- [ ] `nix flake check` green; pre-commit (nixfmt-rfc-style, deadnix, statix)
      green.
