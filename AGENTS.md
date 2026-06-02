# AGENTS.md — nix-nexus Maintenance Authority

> **Purpose.** This document is the single authoritative guide for any AI coding
> agent maintaining, extending, or debugging nix-nexus. It is a living reference,
> not a one-time task list. Every task — from adding a package to onboarding a new
> host — must be grounded in the rules and verification steps here.
>
> **If you are not a Nix/NixOS expert, that is expected.** This document and its
> companion `docs/` guides tell you exactly what to do. For factual NixOS data
> (package names, option paths, versions, Home Manager options), you have the
> `nixos-tools` MCP server. Use it. Do not rely on training-data memory of
> nixpkgs — it drifts by months.

---

## 0. Steering authorities

When this document and an upstream reference conflict, **the upstream reference
wins**. Stop and report the conflict; do not improvise.

| Authority | Where to fetch | Governs |
|---|---|---|
| Dendritic pattern | `https://github.com/mightyiam/dendritic` | `flake.modules.*` namespace, deferred module merge semantics |
| flake-parts manual | `https://flake.parts/` | Option namespacing, `perSystem`, module system rules |
| import-tree README | `https://github.com/vic/import-tree` | Builder API: `addPath`, `filter`, `result` |
| NixOS manual | Use `nixos-tools` MCP (see §2) | NixOS options, module patterns, `lib.*` functions |
| Home Manager manual | Use `nixos-tools` MCP (see §2) | HM options and module patterns |

Use the `fetch` MCP tool to re-read any authority URL before making structural
changes. Do not rely on training-data memory of any of these projects.

---

## 1. What this repository is (plain-terms orientation)

nix-nexus manages the complete system configuration for a fleet of eight machines
(NixOS workstations, NixOS LXC servers, and non-NixOS standalone nodes) using a
single Nix flake. It uses the **dendritic pattern**: every `.nix` configuration
file announces its own name into a shared registry, and hosts compose themselves
by picking names from that registry — not by importing files by path.

The practical consequence: adding a new capability is just adding a new `.nix`
file. No aggregator file, no central import list, no wiring in `flake.nix`.

**Read these before making non-trivial changes:**
- `docs/architecture.md` — how the pattern works end-to-end
- `docs/cookbook.md` — step-by-step recipes for the most common tasks

---

## 2. The nixos-tools MCP server — your factual grounding tool

**Use `nixos-tools` before asserting any fact about nixpkgs, NixOS, or Home
Manager.** Training data lags nixpkgs by months. An attribute path, option name,
or package version that seems right from memory may be renamed, removed, or
split. Always verify.

### When to use it

| Situation | What to query |
|---|---|
| Adding a package — need the exact attribute path | `nix` → `action: search`, `query: <package-name>` |
| Enabling a NixOS service — need the option path | `nix` → `action: search`, `type: options`, `query: <service-name>` |
| Adding a Home Manager option | `nix` → `action: search`, `source: home-manager`, `query: <topic>` |
| Checking which nixpkgs channel has a version | `nix_versions` → `package: <attr>`, `version: <ver>` |
| Looking up NixOS wiki guidance | `nix` → `action: search`, `source: nixos-wiki`, `query: <topic>` |
| Finding nix.dev tutorials or examples | `nix` → `action: search`, `source: nix.dev`, `query: <topic>` |
| Confirming a package is in the binary cache | `nix` → `action: cache`, `query: <attr>` |

### Concrete query examples (copy these shapes exactly)

```json
// Find a package by name
{ "action": "search", "query": "tailscale" }

// Find a NixOS option for a service
{ "action": "search", "type": "options", "query": "services.synapse" }

// Find a Home Manager option
{ "action": "search", "source": "home-manager", "query": "programs.git" }

// Check version history — which nixpkgs commit shipped version X?
// nix_versions tool:
{ "package": "tailscale", "version": "1.80.0" }

// Check binary cache availability
{ "action": "cache", "query": "python312" }

// Read the NixOS wiki page on a topic
{ "action": "search", "source": "nixos-wiki", "query": "ZFS" }

// Find nix.dev tutorials
{ "action": "search", "source": "nix.dev", "query": "flake inputs" }
```

**Rule:** If you are about to write a package attribute path, NixOS option path,
or Home Manager option path that you did not just verify with `nixos-tools` in
this session, stop and verify it first.

---

## 3. Architecture invariants — what must never be violated

These are the non-negotiable rules of the dendritic pattern. Violating any of
them breaks the architecture, even if the result evaluates correctly.

### 3.1 Every `.nix` file under `modules/`, `hosts/`, `profiles/` is a flake-parts fragment

Every file must have the outermost shape:

```nix
# No inputs needed:
_: {
  flake.modules.nixos.my-module-name = <NixOS module>;
}

# With inputs:
{ inputs, config, ... }: {
  flake.nixosConfigurations.myhostname = inputs.nixpkgs.lib.nixosSystem { ... };
}
```

Files starting with `_` in any path segment are excluded from auto-discovery.
Everything else is included automatically — do not add explicit imports.

### 3.2 Hosts compose by name, never by path

Inside any NixOS module delivered by the registry, the `imports` list must only
use names from `nixosModules.*` or `homeManagerModules.*`. Never use `import
./relative/path.nix` inside a module that is itself part of the registry.

```nix
# CORRECT — name lookup from registry
imports = [
  nixosModules.hardware-z16
  nixosModules.workstation-default
  nixosModules.desktop-sway
];

# WRONG — path import breaks the pattern
imports = [
  ./hardware/z16.nix
  ../profiles/workstation.nix
];
```

### 3.3 No aggregator files

An aggregator file is a fragment whose only purpose is to import other named
modules — it adds no configuration of its own. These are forbidden. Instead,
use `lib.types.deferredModule` merge semantics: multiple files can share the
same registry key and the module system merges their contents.

```nix
# WRONG — aggregator (imports-only fragment)
_: {
  flake.modules.nixos.my-stack = { nixosModules, ... }: {
    imports = [
      nixosModules.my-stack-part-a
      nixosModules.my-stack-part-b
    ];
  };
}

# CORRECT — both files contribute to the same key directly
# File: modules/my-stack/part-a.nix
_: {
  flake.modules.nixos.my-stack = _: {
    services.foo.enable = true;
  };
}
# File: modules/my-stack/part-b.nix
_: {
  flake.modules.nixos.my-stack = _: {
    services.bar.enable = true;
  };
}
```

### 3.4 Custom options belong in `nix-nexus.<subsystem>.*`

When a module declares custom options, they must be namespaced at depth three
or deeper: `nix-nexus.<subsystem>.<option>`. Options at depth two
(`nix-nexus.<option>`) are forbidden.

```nix
# CORRECT
options.nix-nexus.networking.tailscale.homeSSIDs = lib.mkOption { ... };
options.nix-nexus.zfs.arcMax = lib.mkOption { ... };

# WRONG — too flat
options.nix-nexus.tailscale.homeSSIDs = lib.mkOption { ... };
```

### 3.5 `lib/` is not auto-discovered

Files under `lib/` are plain Nix helpers (derivations, pure data). They are not
flake-parts fragments and are not auto-discovered. Import them explicitly by
relative path at the call site.

### 3.6 `flake.nix` is a pass-through — do not hard-code module wiring there

`flake.nix` contains one composable import-tree builder and nothing else:

```nix
outputs =
  inputs:
  let
    fleet = builtins.foldl' (it: p: it.addPath p) inputs.import-tree [
      ./modules
      ./hosts
      ./profiles
    ];
  in
  inputs.flake-parts.lib.mkFlake { inherit inputs; } fleet.result;
```

To add a new subtree, append one `addPath` path to that list. No other changes
to `flake.nix` should be needed for routine maintenance.

### 3.7 Standalone HM configurations use `lib.types.raw`

`flake.homeConfigurations` uses `lib.types.raw`, not `deferredModule`. Each
standalone HM configuration (`"user@host"`) has exactly one definition. This
is correct and intentional — do not change it.

---

## 4. File placement and naming conventions

Before creating or moving any file, verify where it belongs:

| What you're adding | Where it goes | Registry key convention |
|---|---|---|
| Core system policy (applied to all machines of a role) | `modules/core/<subsystem>.nix` | `core-<subsystem>` |
| Role bundle (groups of core modules) | `profiles/<role>/default.nix` | `<role>-default` |
| Hardware aspect (platform-specific) | `modules/hardware/<platform>/` | `hardware-<platform>` |
| Hardware HM aspect (compositor-specific) | `modules/hardware/<platform>/` | `hardware-<platform>-<compositor>-home` |
| Desktop compositor (NixOS) | `modules/desktop/<compositor>.nix` | `desktop-<compositor>` |
| Desktop HM companion | `modules/desktop/<name>-home.nix` | `desktop-<name>-home` |
| Service stack | `modules/services/<stack>/` | `services-<stack>` |
| Development toolchain / packages | `modules/programs/<aspect>.nix` | `development-default` (merged) |
| User HM profile | `modules/user/<aspect>.nix` | `user-<aspect>` |
| Host machine-specific config | `hosts/<hostname>/default.nix` | `<hostname>-default` |
| Host HM profile | `hosts/<hostname>/home.nix` | `<hostname>-home` |
| HM wiring (NixOS-side) | `hosts/<hostname>/<user>-hm.nix` | `hm-<user>-<hostname>` |
| Flake assembly (nixosSystem call) | `modules/flake/nixos-<hostname>.nix` | (no registry key — sets `flake.nixosConfigurations`) |
| Standalone HM assembly | `modules/flake/hm-<user>-<hostname>.nix` | (no registry key — sets `flake.homeConfigurations`) |
| Pure helpers / derivations | `lib/<name>.nix` | (no key — plain Nix, imported by path) |

**Naming rules:**
- Registry keys are always `kebab-case`.
- A file may register to a key that already exists — the module system merges
  contributions. This is how multi-file stacks work.
- Files with a path segment starting with `_` are excluded from discovery.

---

## 5. Universal operating rules

Follow these on every task, every commit:

1. **Read before asserting.** If you have not opened a file in this session, you
   do not know its contents. Use `Read` before editing, `ls` before claiming a
   directory structure.

2. **Verify with `nixos-tools` before writing any package or option path.** Never
   write `pkgs.somePackage` or `services.something.enable` from memory alone.
   Query `nixos-tools` first (see §2).

3. **One logical change per commit.** Do not batch unrelated edits. Linting and
   closure verification are per-commit.

4. **Lint before committing:**
   ```bash
   nix develop --command pre-commit run --files <space-separated changed files>
   ```
   All three hooks must pass: `nixfmt-rfc-style` (formatting), `deadnix`
   (unused bindings), `statix` (Nix anti-patterns).

5. **Evaluate after committing:**
   ```bash
   nix flake check
   ```
   This evaluates the full module tree for all hosts. Must pass green.

6. **No store-path drift without written justification.** If a closure baseline
   exists in `.agents/SIGNOFF.md` and you observe hash changes, investigate and
   document before proceeding. "It changed" is not a justification.

7. **Honest uncertainty.** If you cannot confirm a change is behavior-preserving,
   stop and report. A blocked task accurately described is better than a silently
   broken configuration.

8. **No invented patterns.** Every structural choice must trace to §0 authorities
   or the existing codebase. If the right approach is unclear, read the authority
   first. Gaps are open questions, not licence to fill from memory.

---

## 6. Validation protocol

Run these steps for every substantive change. The order matters.

### Step 1 — Pre-edit baseline (for changes with closure risk)

Capture derivation hashes before touching any file:

```bash
# For all NixOS hosts:
for host in sweet16 petunia avina hermes openclaw; do
  echo "$host: $(nix path-info --derivation .#nixosConfigurations.$host.config.system.build.toplevel 2>/dev/null)"
done

# For standalone HM configs:
for cfg in groot@dualie groot@forge groot@rk3588; do
  echo "$cfg: $(nix path-info --derivation ".#homeConfigurations.\"$cfg\".activationPackage" 2>/dev/null)"
done
```

Save this output. You will compare it after your changes.

### Step 2 — Pre-commit lint

```bash
# Run on every file you changed:
nix develop --command pre-commit run --files modules/foo/bar.nix hosts/sweet16/default.nix

# Or run on all tracked changes:
nix develop --command pre-commit run
```

Fix all failures before proceeding. Common failures:
- `nixfmt-rfc-style`: auto-formats; re-stage the reformatted file.
- `deadnix`: remove the flagged unused binding.
- `statix`: read the warning; fix the anti-pattern. Common ones:
  - `{ ... }:` empty pattern → change to `_:`.
  - `with pkgs;` → use explicit `pkgs.` prefix.

### Step 3 — Flake evaluation

```bash
nix flake check
```

This must complete without errors. Warnings are acceptable but should be
investigated if new.

### Step 4 — Closure comparison

After committing, re-run the Step 1 commands and compare. Expected outcomes:

| Change type | Expected outcome |
|---|---|
| Adding/changing a package | Only affected hosts drift; hash change is expected |
| Structural refactor (rename, move) | Zero drift — same packages, same configs |
| Option namespace rename | Zero drift — same generated config |
| New host added | New entry only; no other hosts drift |

For any unexpected drift: inspect the derivation JSON to find the root cause:
```bash
# Compare two drvs:
diff <(nix show-derivation /nix/store/...-A.drv | python3 -m json.tool) \
     <(nix show-derivation /nix/store/...-B.drv | python3 -m json.tool)
```

### Step 5 — Sign off

For significant changes (new hosts, structural refactors, registry type changes),
append a sign-off block to `.agents/SIGNOFF.md` documenting:
- What changed
- Pre/post hashes for each host
- Explanation for any drift

---

## 7. Common maintenance tasks

The `docs/cookbook.md` contains step-by-step recipes for:
- Adding a NixOS system module
- Adding a Home Manager module
- Adding a new system user
- Adding a multi-file application stack (deferredModule merge)
- Adding a new NixOS workstation host
- Adding a new NixOS server/LXC host
- Adding a standalone Home Manager host

**Read the relevant recipe before starting.** This section summarizes the
decision points that cross-cut all tasks.

### 7.1 Deciding where a new module belongs

Ask:
1. Is it machine-specific hardware configuration? → `hosts/<hostname>/` or
   `modules/hardware/<platform>/`
2. Is it a user-level (Home Manager) concern? → `modules/user/` or
   `hosts/<hostname>/home.nix`
3. Is it a system service or daemon? → `modules/services/<stack>/`
4. Is it a desktop/compositor concern? → `modules/desktop/`
5. Is it a development tool or system package? → `modules/programs/`
6. Is it a foundational policy applied fleet-wide? → `modules/core/`

### 7.2 Deciding the registry key

1. Check naming conventions in §4.
2. Check whether an existing key accepts contributions (multi-file stacks). If
   you're adding to an existing stack (e.g., `services-matrix`), use the same key
   — the module system merges contributions automatically.
3. If creating a new key: verify it does not collide with an existing one:
   ```bash
   grep -r 'flake\.modules\.\(nixos\|homeManager\)\.' modules/ hosts/ profiles/ \
     | grep -o '"[^"]*"' | sort -u
   ```

### 7.3 Adding a flake input

When a new capability requires a new flake input:
1. Add it to the `inputs` attrset in `flake.nix`.
2. Use `inputs.nixpkgs.follows = "nixpkgs"` if the input takes a nixpkgs to
   avoid dependency duplication (verify with `nixos-tools` if unsure).
3. Run `nix flake update <input-name>` to pin it.
4. Commit `flake.nix` and `flake.lock` together.

### 7.4 Pinning a package to a specific nixpkgs commit

When you need to pin a package to avoid a regression or use a specific version:
1. Use `nix_versions` to find the nixpkgs commit that shipped the desired version.
2. Add a pinned input to `flake.nix`:
   ```nix
   pkgs-mything.url = "github:nixos/nixpkgs/<commit-sha>";
   ```
3. Reference it in the consuming module via `inputs.pkgs-mything.legacyPackages.${system}`.

---

## 8. Forbidden anti-patterns

These patterns break the architecture or have been explicitly corrected in this
codebase. Do not reintroduce them.

| Anti-pattern | Why it is forbidden | Correct alternative |
|---|---|---|
| Path imports inside registry modules (`import ./foo.nix`) | Bypasses the name registry; creates tight coupling | Reference by name: `nixosModules.foo` |
| Aggregator-only fragments (imports list with no config) | Pure wiring overhead; eliminated by deferredModule | All leaf files share the same registry key directly |
| `lib.types.raw` for `flake.modules.*` registries | Prevents multi-file stacks; raises conflict on duplicate keys | `lib.types.lazyAttrsOf lib.types.deferredModule` (already set) |
| Custom options at `nix-nexus.<option>` (depth 2) | Violates namespace convention | `nix-nexus.<subsystem>.<option>` (depth 3+) |
| Hard-coding module paths in `flake.nix` | `flake.nix` must be a pass-through | Add the file under `modules/`, `hosts/`, or `profiles/` |
| Writing `with pkgs;` in module files | `statix` flags it; creates implicit scope | Use explicit `pkgs.packageName` |
| Skipping pre-commit hooks (`--no-verify`) | Allows formatting and lint violations to accumulate | Fix the underlying issue |
| Trusting training-data for nixpkgs attribute paths | Nixpkgs drifts monthly; wrong paths cause eval failures | Query `nixos-tools` MCP first |
| Modules that mutate other modules via `mkForce` without justification | Creates hidden coupling; breaks composability | Prefer explicit option values at the host assembly level |

---

## 9. Fleet reference

Current hosts and their assembly structure:

| Host | OS | Arch | Flake assembly | Host module | HM wiring |
|---|---|---|---|---|---|
| sweet16 | NixOS | x86_64 | `modules/flake/nixos-sweet16.nix` | `hosts/sweet16/default.nix` | `hosts/sweet16/ddukes-hm.nix` |
| petunia | NixOS | x86_64 | `modules/flake/nixos-petunia.nix` | `hosts/petunia/default.nix` | `hosts/petunia/ddukes-hm.nix` |
| avina | NixOS | x86_64 | `modules/flake/nixos-avina.nix` | `hosts/avina/default.nix` | `hosts/avina/ddukes-hm.nix` |
| hermes | NixOS | x86_64 | `modules/flake/nixos-hermes.nix` | `hosts/hermes/default.nix` | `hosts/hermes/groot-hm.nix` |
| openclaw | NixOS | x86_64 | `modules/flake/nixos-openclaw.nix` | `hosts/openclaw/default.nix` | `hosts/openclaw/groot-hm.nix` |
| dualie | Debian (standalone HM) | x86_64 | `modules/flake/hm-groot-dualie.nix` | `hosts/dualie/home.nix` | n/a |
| forge | Linux (standalone HM) | x86_64 | `modules/flake/hm-groot-forge.nix` | `hosts/forge/home.nix` | n/a |
| rk3588 | Armbian (standalone HM) | aarch64 | `modules/flake/hm-groot-rk3588.nix` | `hosts/rk3588/home.nix` | n/a |

**Current custom `nix-nexus.*` options:**

| Option path | Declared in | Callers |
|---|---|---|
| `nix-nexus.zfs.*` | `modules/core/zfs.nix` | `hosts/sweet16/default.nix`, `hosts/petunia/default.nix` |
| `nix-nexus.networking.tailscale.homeSSIDs` | `modules/core/networking.nix` | `hosts/sweet16/default.nix` |

---

## 10. Troubleshooting

### "attribute 'X' missing" during `nix flake check`

The host's assembly (`modules/flake/nixos-<host>.nix`) references a registry key
that does not exist. Common causes:
1. The file that should register key `X` has a typo in its key string.
2. The file is under a path segment starting with `_` and was excluded.
3. The file was deleted without updating the caller.

Find where the key is expected: `grep -r '"X"' modules/ hosts/`.
Find where it should be registered: `grep -r 'flake.modules.nixos.X' modules/ hosts/`.

### "type error" or "cannot merge" in registry

`flake.homeConfigurations` uses `lib.types.raw` — it cannot have duplicate keys.
If two files register `"user@host"`, one must be removed.

`flake.modules.nixos` and `flake.modules.homeManager` use `lib.types.deferredModule`
— duplicate keys are expected and merged correctly.

### `statix` warning: "empty pattern `{ ... }:`"

Change `{ ... }:` to `_:` when no arguments from the set are used.

### `deadnix` failure: unused binding

Remove the binding. If it is needed for documentation, there is no exception —
Nix is a functional language; unused bindings are dead code.

### Pre-commit reformats a file after you edit it

`nixfmt-rfc-style` auto-reformats on check. Re-stage the reformatted file with
`git add <file>` and re-run pre-commit. Do not fight the formatter.

### Unexpected closure drift after a structural change

Structural changes (renames, key merges) should produce zero drift. If you see
drift, compare the pre/post derivations:
```bash
diff <(nix show-derivation OLD.drv | python3 -m json.tool) \
     <(nix show-derivation NEW.drv | python3 -m json.tool)
```
Trace the cascade from the differing drv upward to find what changed. Common
causes: list-merge order changed (kernel params, package lists), evaluation
order changed by `deferredModule` wrapping.

---

## 11. Document map

```
AGENTS.md                     ← you are here (maintenance authority)
docs/
├── architecture.md           ← how the dendritic pattern works end-to-end
├── cookbook.md               ← step-by-step recipes for common tasks
├── hardware.md               ← OLED, AMD P-State, hybrid GPU
├── cachyos-kernel.md         ← CachyOS kernel, ZFS, BBR3
├── packages.md               ← pinned DevOps tool and driver versions
├── storage.md                ← CephFS and ZFS dataset strategies
├── terminal.md               ← Kitty/Tmux config and Bash aliases
├── non-nixos.md              ← standalone HM migration guide
└── devenv.md                 ← declarative dev environments
.agents/
├── SIGNOFF.md                ← closure baseline and drift sign-offs
├── validation.md             ← baseline capture and verification scripts
└── scripts/
    ├── capture-baseline.sh   ← captures drv hashes for all hosts
    └── verify-hosts.sh       ← compares current vs baseline hashes
```
