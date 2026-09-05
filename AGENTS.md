# AGENTS.md — nix-nexus Maintenance Authority

> **Purpose.** This document is the one authority for each AI coding agent.
> The agent maintains, extends, or fixes nix-nexus. This document is a living reference.
> It is not a one-time task list. Every task must follow the rules and checks
> in this document. Tasks range from adding a package to configuring a new
> host.
>
> **If you are not a Nix or NixOS expert, that is normal.** This document and
> the `docs/` guides tell you what to do. Use the `nixos-tools` MCP server for
> facts about NixOS. Facts include package names, option paths, versions, and
> Home Manager options. Do not trust training-data memory of nixpkgs. Training
> data can be months behind nixpkgs.

---

## 0. Steering authorities

When this document and an upstream reference conflict, **the upstream reference
wins**. Stop. Report the conflict. Do not improvise.

| Authority | Where to fetch | Governs |
|---|---|---|
| Dendritic pattern | `https://github.com/mightyiam/dendritic` | `flake.modules.*` namespace, deferred module merge semantics |
| flake-parts manual | `https://flake.parts/` | Option namespacing, `perSystem`, module system rules |
| import-tree README | `https://github.com/vic/import-tree` | Builder API: `addPath`, `filter`, `result` |
| NixOS manual | Use `nixos-tools` MCP (see §2) | NixOS options, module patterns, `lib.*` functions |
| Home Manager manual | Use `nixos-tools` MCP (see §2) | HM options and module patterns |

Use the `fetch` MCP tool. Read any authority URL again before you make
structural changes. Do not trust training-data memory of these projects.

---

## 1. What this repository is (plain-terms orientation)

nix-nexus manages the full system configuration for a fleet of seven machines.
The fleet has NixOS workstations, NixOS LXC servers, and non-NixOS standalone
nodes. nix-nexus uses one Nix flake for all machines. nix-nexus uses the
**dendritic pattern**. In this pattern, each `.nix` configuration file
announces its own name in a shared registry. Hosts then choose names from
that registry to build their configuration. Hosts compose their configuration
from registry names, not from path imports.

As a result, you add a new capability with one new `.nix` file. You do not
need an aggregator file. You do not need a central import list. You do not
need wiring in `flake.nix`.

**Read these documents before you make a change that is not trivial:**
- `docs/architecture.md` — explains how the pattern works, from start to end
- `docs/cookbook.md` — lists steps for the most common tasks
- `docs/workflow.md` — describes the daily work loop for humans. The loop
  includes the shell, lint, drift check, sign-off, and deploy steps. This
  guide is lighter than this document. It is safe for new team members to read.

---

## 2. The nixos-tools MCP server — your factual grounding tool

**Use `nixos-tools` before you state any fact about nixpkgs, NixOS, or Home
Manager.** Training data can be months behind nixpkgs. An attribute path,
option name, or package version from memory can be wrong. Nixpkgs can rename,
remove, or split it. Always check it first.

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

Before you write a package attribute path, a NixOS option path, or a Home
Manager option path, check it with `nixos-tools` in this session. If you have
not checked it, stop. Check it first.

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
  nixosModules.desktop-hyprland
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
| Standalone HM assembly | `modules/flake/hm-<user>.nix` (one file maps every host for that user, e.g. `modules/flake/hm-groot.nix`) | (no registry key — sets `flake.homeConfigurations`) |
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
   .agents/scripts/preflight.sh <space-separated changed files>
   ```
   All three hooks must pass: `nixfmt` (formatting, RFC 166 style), `deadnix`
   (unused bindings), `statix` (Nix anti-patterns). The runner is `prek`, not
   `pre-commit` — `pre-commit` is not installed. `preflight.sh` also runs
   `nix flake check --impure`; `--impure` is mandatory for every `nix develop`
   and `nix flake check` in this repo.

5. **Evaluate after committing:**
   ```bash
   nix flake check
   ```
   This evaluates the full module tree for all hosts. Must pass green.

6. **No store-path drift without written justification.** If a closure baseline
   is recorded in `.agents/baseline.json` and you observe hash changes,
   investigate and document before proceeding. "It changed" is not a
   justification.

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
for host in sweet16 petunia avina hermes; do
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
# Run on every file you changed (lint + full flake evaluation):
.agents/scripts/preflight.sh modules/foo/bar.nix hosts/sweet16/default.nix

# Lint only, inside an already-entered devshell:
prek run --files modules/foo/bar.nix
prek run   # all staged files
```

Fix all failures before proceeding. Common failures:
- `nixfmt`: auto-formats; re-stage the reformatted file.
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
run the writer and supply judgment on stdin:

```bash
.agents/scripts/signoff.sh --slug <kebab-slug> <<'EOF'
### Expected-drift set
...
### Actual vs expected
...
EOF
```

It writes an immutable entry under `.agents/signoff/` and replaces
`.agents/baseline.json` with the new per-config state. Never hand-write a
store hash or hand-author an entry — the script generates every fact, you
supply only the judgment.

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
| dualie | Debian (standalone HM) | x86_64 | `modules/flake/hm-groot.nix` | `hosts/dualie/home.nix` | n/a |
| forge | Linux (standalone HM) | x86_64 | `modules/flake/hm-groot.nix` | `hosts/forge/home.nix` | n/a |
| rk3588 | Armbian (standalone HM) | aarch64 | `modules/flake/hm-groot.nix` | `hosts/rk3588/home.nix` | n/a |

**Current custom `nix-nexus.*` options:**

| Option path | Declared in | Callers |
|---|---|---|
| `nix-nexus.zfs.*` | `modules/core/zfs.nix` | `hosts/sweet16/default.nix`, `hosts/petunia/default.nix` |
| `nix-nexus.networking.tailscale.homeSSIDs` | `modules/core/networking.nix` | `hosts/sweet16/default.nix` |
| `nix-nexus.virtualization.microvm.*` | `modules/core/microvm-host.nix` | `hosts/sweet16/default.nix` |
| `nix-nexus.secrets.sops.*` | `modules/core/sops.nix` | `hosts/avina/default.nix`, `hosts/hermes/secrets.nix` |
| `nix-nexus.tpm2.users` | `modules/core/tpm2.nix` | `hosts/sweet16/default.nix`, `hosts/petunia/default.nix` |
| `nix-nexus.theme.*` | `modules/desktop/theme.nix` | `hosts/sweet16/default.nix` |
| `nix-nexus.kernel.cachyos.*` | `modules/hardware/kernel/cachyos.nix` | `hosts/sweet16/default.nix`, `hosts/petunia/default.nix` |
| `nix-nexus.user.dev.*` (Home Manager) | `modules/user/dev-home.nix` | `modules/user/home.nix`, `hosts/dualie/home.nix`, `hosts/forge/home.nix`, `hosts/rk3588/home.nix` |

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

`nixfmt` auto-reformats on check. Re-stage the reformatted file with
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

### Expected `nix flake check` output

A clean `nix flake check --impure` run always emits these four warning
lines. None of them indicates a defect.

1. `warning: unknown flake output 'modules'`. The `flake.modules.*` registry
   is not a standard flake output. flake-parts populates it correctly, and
   `nix flake check` does not recognise it.
2. `warning: The check omitted these incompatible systems: aarch64-linux`.
   `modules/flake/systems.nix` declares both `x86_64-linux` and
   `aarch64-linux`. Without `--all-systems`, `nix flake check` evaluates only
   the current system and reports the other one as omitted.
3. `evaluation warning: The package 'devenv-up' is deprecated...`. The devenv
   2.2.0 flake module emits this line unconditionally for its default package.
4. `evaluation warning: The package 'devenv-test' is deprecated...`. Same
   source as line 3.

Treat any other warning as a defect and investigate it before you proceed.

---

## 11. Document map

```
AGENTS.md                       ← you are here (maintenance authority)
README.md                       ← project overview, fleet table, directory map, quick start
docs/
├── architecture.md             ← how the dendritic pattern works end-to-end
├── cookbook.md                 ← step-by-step recipes for common tasks
├── workflow.md                 ← human-facing day-to-day dev loop (start here)
├── hardware.md                 ← OLED, AMD P-State, hybrid GPU
├── cachyos-kernel.md           ← CachyOS kernel, ZFS, BBR3
├── packages.md                 ← pinned DevOps tool versions
├── storage.md                  ← CephFS and ZFS dataset strategies
├── terminal.md                 ← Kitty/Tmux config and Bash aliases
├── non-nixos.md                ← standalone HM migration guide
├── devenv.md                   ← declarative dev environments
├── petunia.md                  ← TPM2 auto-unlock, dual GPU, rebuild procedure
├── petunia-sbom.md             ← petunia inference stack SBOM (ROCm, HIP, Vulkan, Mesa versions)
├── secrets.md                  ← sops-nix / secretspec / Vault layering, TPM2 posture per host
├── permafrost-host.md          ← permafrost microvm host module: bridge, NAT, kvm policy, store settings
├── hermes.md                   ← Hermes LXC host: hermes-agent gateway, Matrix, Petunia-backed LLM
├── upgrading.md                ← routine updates, major release upgrades, rollback, auto-upgrades
└── _archive/                   ← historical planning docs, not part of the doc index (superpowers/)
hosts/avina/
├── README.md                   ← avina LXC container overview and Matrix 2.0 stack summary
└── PROTOCOL_REFERENCE.md       ← standards and security decisions behind the Matrix 2.0 stack
lib/
├── authorized-keys.nix         ← TPM-sealed SSH public keys, per host
├── avina/site-config.nix       ← Avina domain constants
├── context-mode.nix            ← context-mode npm package derivation
├── context-mode-hermes.nix     ← hermes-agent Python plugin package for context-mode
├── context-mode-lock.json      ← npm lockfile for context-mode.nix
├── custom-scripts.nix          ← battery-alert, llm-init, and other helper scripts
├── hermes-agent/               ← vendored hermes-agent package, patch, version-check hook
├── keymap.nix                  ← shared tmux/fish multiplexer keymap actions
├── openclaude.nix              ← Claude npm package derivation
├── openclaude-lock.json        ← npm lockfile for openclaude.nix
├── pinned-pkgs.nix             ← helper to instantiate a pinned nixpkgs flake input
├── shell-aliases.nix           ← bash/fish shared shell aliases
└── themes/                     ← theme registry: color schemes, wallpapers
.agents/
├── baseline.json               ← current per-config drv state + signed_off_through
├── signoff/                    ← one immutable generated entry per sign-off
├── signoff-archive.md          ← historical: hand-authored sign-offs, 2026-06→08
├── validation.md               ← script toolbox reference (current-state)
├── phase-A.md                  ← historical: dendritic refactor phase A record
├── phase-B.md                  ← historical: dendritic refactor phase B record
├── phase-C.md                  ← historical: dendritic refactor phase C record
└── scripts/
    ├── lib.sh                  ← fleet lists + clean per-rev drv eval helper
    ├── signoff.sh              ← the only sign-off writer: entry + baseline.json
    ├── verify-drift.sh         ← per-config drv diff between two revs
    ├── consumers.sh            ← recursive registry-key/input consumer lookup
    ├── lock-diff.sh            ← node-by-node flake.lock diff via jq
    ├── preflight.sh            ← pre-commit + nix flake check gate
    ├── cert-check.sh           ← ephemeral Vault SSH cert validity check
    ├── build-host.sh           ← timed local build with cache stats
    ├── deploy-host.sh          ← cert-check → ssh probe → nixos-rebuild → verify
    ├── verify-generation.sh    ← remote system profile check
    ├── hook-commit-reminder.sh ← PostToolUse(Bash) hook: nudge validation after a commit
    └── hook-push-guard.sh      ← PreToolUse(Bash) hook: block push without a sign-off record
modules/flake/
└── checks.nix                  ← devenv.shells.default: devshell, git-hooks, claude.code wiring
.envrc                          ← direnv entry (`use flake --impure`); tracked
.claude/
├── settings.json               ← generated by devenv (claude.code, modules/flake/checks.nix); untracked
└── agents/
    ├── upstream-scout.md       ← verifies upstream facts (haiku)
    ├── nix-implementer.md      ← writes and commits module/host changes (sonnet)
    ├── closure-validator.md    ← judges drift, signs off via signoff.sh (sonnet)
    └── fleet-deployer.md       ← deploys validated commits to the fleet (sonnet)
```

---

## 12. Agent workflow

The maintenance pipeline is split between deterministic scripts (§ toolbox
below, in `.agents/scripts/`) and thin judgment-only agents
(`.claude/agents/*.md`). Scripts own *how* — clean per-rev evals, drift
comparison, lint gates, deploys. Agents own *whether/why* — where code goes,
whether drift is expected, when it's safe to deploy. This keeps LLM context
spent on judgment, not on restating deterministic process in every prompt.

### Roster

| Agent | Phase | Trigger |
|---|---|---|
| `upstream-scout` | scout | a package attr, NixOS/HM option, or flake input schema needs verifying and isn't already established this session |
| `nix-implementer` | implement | facts are in hand; a module/host file needs writing and committing |
| `closure-validator` | validate | a commit could affect an evaluated host/HM config; judges actual vs. expected drift and signs off via `signoff.sh` |
| `fleet-deployer` | deploy | a validated commit needs to reach one or more live hosts |

### Standard pipeline

scout → implement (`preflight.sh` per commit) → validate → deploy. The main
session orchestrates: it dispatches each agent, relays their conclusions,
and makes the final call — it does not re-derive their work. Trivial
doc-only edits (no module/host/option changes) skip the pipeline entirely;
just edit and commit.

### Script toolbox

See `.agents/validation.md` for the full contract of each script (args,
output format, exit codes). Summary:

| Script | Purpose |
|---|---|
| `lib.sh` | fleet host/HM lists, clean per-rev eval helper (sourced only) |
| `signoff.sh` | the only sign-off writer: generates an entry under `.agents/signoff/` and replaces `.agents/baseline.json` |
| `verify-drift.sh` | per-config drv comparison between two revs |
| `consumers.sh` | recursively resolves which hosts reach a registry key or flake input |
| `lock-diff.sh` | node-by-node `flake.lock` diff |
| `preflight.sh` | pre-commit hooks + `nix flake check` |
| `cert-check.sh` | validates the ephemeral Vault SSH cert |
| `build-host.sh` | timed local build with cache stats |
| `deploy-host.sh` | cert-check → ssh probe → `nixos-rebuild --target-host` → generation verify |
| `verify-generation.sh` | remote system profile vs. expected toplevel |

### Mechanical hooks

Below the agent tier sits a mechanical tier: two Claude Code hooks, declared
in `modules/flake/checks.nix` (`devenv.shells.default.claude.code.hooks`) and
generated into `.claude/settings.json` by devenv on shell entry, deterministic
and zero-token. They don't judge — they notice a pattern and nudge the
orchestrating session to dispatch the right judgment agent.

| Hook | Event | Enforces |
|---|---|---|
| `hook-commit-reminder.sh` | `PostToolUse(Bash)` | after a `git commit` whose files match `^(modules\|hosts\|profiles\|flake\.(nix\|lock))`, exits 2 with a stderr reminder to dispatch `closure-validator` before deploy/push |
| `hook-push-guard.sh` | `PreToolUse(Bash)` | before a `git push`, requires every outgoing commit touching evaluated config to be an ancestor of `.signed_off_through` in `.agents/baseline.json` (read as committed at HEAD); exits 2 and blocks otherwise |

`hook-commit-reminder.sh` only fires on an actual `git commit` match and can't
block (`PostToolUse` exit 2 is non-blocking — the commit already happened).

`hook-push-guard.sh` fails open on its own errors: a missing `jq`, any git
probing failure, an unresolvable or empty range, or a `signed_off_through`
naming a sha not in the repo all exit 0. It blocks in exactly two cases — a
config commit provably not covered by the sign-off, and `baseline.json` absent
or malformed at HEAD. The second blocks by deliberate choice rather than
failing open: absence of the record is precisely the gated condition, so
failing open there would make the gate defeatable with `rm`.

Neither hook re-implements judgment already owned by `closure-validator` —
they only detect the precondition for dispatching it. Note the guard binds the
agent, not the human: a push from a plain terminal bypasses it entirely.
