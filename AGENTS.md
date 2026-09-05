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

These rules are non-negotiable for the dendritic pattern. A violation breaks
the architecture. This is true even when the result evaluates correctly.

### 3.1 Every `.nix` file under `modules/`, `hosts/`, `profiles/` is a flake-parts fragment

Every file must have this outermost shape:

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

A file with `_` at the start of any path segment is excluded from
auto-discovery. The system includes every other file automatically. Do not add
explicit imports.

### 3.2 Hosts compose by name, never by path

Inside a NixOS module from the registry, the `imports` list must use only
names from `nixosModules.*` or `homeManagerModules.*`. Never use `import
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

An aggregator file is a fragment that only imports other named modules. It
adds no configuration of its own. Aggregator files are forbidden. Instead, use
`lib.types.deferredModule` merge semantics. Multiple files can share one
registry key. The module system merges their contents.

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

When a module declares custom options, the options must sit at depth three or
deeper: `nix-nexus.<subsystem>.<option>`. Options at depth two
(`nix-nexus.<option>`) are forbidden.

```nix
# CORRECT
options.nix-nexus.networking.tailscale.homeSSIDs = lib.mkOption { ... };
options.nix-nexus.zfs.arcMax = lib.mkOption { ... };

# WRONG — too flat
options.nix-nexus.tailscale.homeSSIDs = lib.mkOption { ... };
```

### 3.5 `lib/` is not auto-discovered

Files under `lib/` are plain Nix helpers. Examples are derivations and pure
data. They are not flake-parts fragments. The system does not auto-discover
them. Import each file explicitly by relative path at the call site.

### 3.6 `flake.nix` is a pass-through — do not hard-code module wiring there

`flake.nix` contains one composable import-tree builder. It contains nothing
else:

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

To add a new subtree, append one `addPath` path to that list. Routine
maintenance should need no other change to `flake.nix`.

### 3.7 Standalone HM configurations use `lib.types.raw`

`flake.homeConfigurations` uses `lib.types.raw`. It does not use
`deferredModule`. Each standalone HM configuration (`"user@host"`) has exactly
one definition. This design is correct and intentional. Do not change it.

---

## 4. File placement and naming conventions

Before you create or move a file, find your task in this table:

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
- Registry keys use `kebab-case`.
- A file can register to a key that already exists. The module system merges
  the contributions. This is how multi-file stacks work.
- A file with a path segment that starts with `_` is excluded from discovery.

---

## 5. Universal operating rules

Follow these rules on every task and every commit:

1. **Read before you assert a fact.** If you have not opened a file in this
   session, you do not know its contents. Use `Read` before you edit a file.
   Use `ls` before you state a directory structure.

2. **Verify with `nixos-tools` before you write any package or option path.**
   Never write `pkgs.somePackage` or `services.something.enable` from memory.
   Query `nixos-tools` first (see §2).

3. **Make one logical change per commit.** Do not batch unrelated edits. Lint
   and verify the closure for each commit.

4. **Lint before you commit:**
   ```bash
   .agents/scripts/preflight.sh <space-separated changed files>
   ```
   All three hooks must pass. `nixfmt` checks formatting under RFC 166 style.
   `deadnix` finds unused bindings. `statix` finds Nix anti-patterns. The
   runner is `prek`, not `pre-commit` — `pre-commit` is not installed.
   `preflight.sh` also runs `nix flake check --impure`. `--impure` is
   mandatory for every `nix develop` and `nix flake check` in this repo.

5. **Evaluate the flake after you commit:**
   ```bash
   nix flake check
   ```
   This step evaluates the full module tree for all hosts. It must pass
   green.

6. **Write a justification for any store-path drift.** A closure baseline
   sits in `.agents/baseline.json`. If you see a hash change, investigate it
   and document the cause before you proceed. "It changed" is not a
   justification.

7. **Report honest uncertainty.** If you cannot confirm a change keeps the
   same behavior, stop and report it. A blocked task with a clear report is
   better than a silently broken configuration.

8. **Do not invent patterns.** Every structural choice must trace to a §0
   authority or the existing codebase. If the right approach is unclear,
   read the authority first. A gap is an open question, not a licence to
   fill from memory.

---

## 6. Validation protocol

Run these steps for every substantive change. Run the steps in order.

### Step 1 — Pre-edit baseline (for changes with closure risk)

Capture derivation hashes before you touch any file.

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

Fix all failures before you proceed. Common failures:
- `nixfmt`: auto-formats the file. Re-stage the reformatted file.
- `deadnix`: remove the flagged unused binding.
- `statix`: read the warning. Fix the anti-pattern. Common ones:
  - `{ ... }:` empty pattern → change to `_:`.
  - `with pkgs;` → use explicit `pkgs.` prefix.

### Step 3 — Flake evaluation

```bash
nix flake check
```

This step must complete without errors. Warnings are acceptable. Investigate
any new warning.

### Step 4 — Closure comparison

Commit your change. Re-run the Step 1 commands. Compare the results.
Expected outcomes:

| Change type | Expected outcome |
|---|---|
| Adding/changing a package | Only affected hosts drift; hash change is expected |
| Structural refactor (rename, move) | Zero drift — same packages, same configs |
| Option namespace rename | Zero drift — same generated config |
| New host added | New entry only; no other hosts drift |

For any unexpected drift: inspect the derivation JSON. Find the root cause.
```bash
# Compare two drvs:
diff <(nix show-derivation /nix/store/...-A.drv | python3 -m json.tool) \
     <(nix show-derivation /nix/store/...-B.drv | python3 -m json.tool)
```

### Step 5 — Sign off

For significant changes, run the writer. Significant changes include new
hosts, structural refactors, and registry type changes. Supply judgment on
stdin:

```bash
.agents/scripts/signoff.sh --slug <kebab-slug> <<'EOF'
### Expected-drift set
...
### Actual vs expected
...
EOF
```

It writes an immutable entry under `.agents/signoff/`. It replaces
`.agents/baseline.json` with the new per-config state. Never hand-write a
store hash. Never hand-author an entry. The script generates every fact. You
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

**Read the relevant recipe before you start.** This section lists the
decision points that apply to every task.

### 7.1 Deciding where a new module belongs

Ask these questions:
1. Is it machine-specific hardware configuration? → `hosts/<hostname>/` or
   `modules/hardware/<platform>/`
2. Is it a user-level (Home Manager) concern? → `modules/user/` or
   `hosts/<hostname>/home.nix`
3. Is it a system service or daemon? → `modules/services/<stack>/`
4. Is it a desktop/compositor concern? → `modules/desktop/`
5. Is it a development tool or system package? → `modules/programs/`
6. Is it a foundational policy applied fleet-wide? → `modules/core/`

### 7.2 Deciding the registry key

1. Check the naming conventions in §4.
2. Check whether an existing key accepts contributions. Multi-file stacks
   accept contributions. If you add to an existing stack, for example
   `services-matrix`, use the same key. The module system merges
   contributions automatically.
3. If you create a new key, check that it does not collide with an existing
   one.
   ```bash
   grep -r 'flake\.modules\.\(nixos\|homeManager\)\.' modules/ hosts/ profiles/ \
     | grep -o '"[^"]*"' | sort -u
   ```

### 7.3 Adding a flake input

Follow these steps when a new capability needs a new flake input.
1. Add the input to the `inputs` attrset in `flake.nix`.
2. Use `inputs.nixpkgs.follows = "nixpkgs"` if the input takes a nixpkgs.
   This step avoids dependency duplication. Verify with `nixos-tools` if you
   are unsure.
3. Run `nix flake update <input-name>` to pin the input.
4. Commit `flake.nix` and `flake.lock` together.

### 7.4 Pinning a package to a specific nixpkgs commit

Follow these steps when you need to pin a package to avoid a regression or
to use a specific version.
1. Use `nix_versions` to find the nixpkgs commit that shipped the version
   you want.
2. Add a pinned input to `flake.nix`:
   ```nix
   pkgs-mything.url = "github:nixos/nixpkgs/<commit-sha>";
   ```
3. Reference the input in the consuming module through
   `inputs.pkgs-mything.legacyPackages.${system}`.

---

## 8. Forbidden anti-patterns

Each pattern in this list is forbidden. Do not add any of these patterns to
this codebase.

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
2. The file's path has a segment that starts with `_`. Auto-discovery excludes the file.
3. Someone deleted the file. The caller still references the old key.

Find where the key is expected: `grep -r '"X"' modules/ hosts/`.
Find where it should be registered: `grep -r 'flake.modules.nixos.X' modules/ hosts/`.

### "type error" or "cannot merge" in registry

`flake.homeConfigurations` uses `lib.types.raw`. This type forbids duplicate keys.
If two files register `"user@host"`, remove one of them.

`flake.modules.nixos` and `flake.modules.homeManager` use `lib.types.deferredModule`.
This type expects duplicate keys and merges them correctly.

### `statix` warning: "empty pattern `{ ... }:`"

Change `{ ... }:` to `_:` when no arguments from the set are used.

### `deadnix` failure: unused binding

Remove the binding. There is no exception for documentation.
Nix is a functional language. Unused bindings are dead code.

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

The maintenance pipeline splits work into two layers. Deterministic scripts
do the mechanical steps. The scripts live in `.agents/scripts/` (see the
toolbox below). Judgment-only agents make the decisions. The agents live in
`.claude/agents/*.md`. Scripts run clean per-revision evaluations, compare
drift, apply lint gates, and deploy code. Agents decide where code goes,
whether drift is expected, and when a deploy is safe. This design saves
LLM context for judgment. Agents do not restate the deterministic process
in every prompt.

### Roster

| Agent | Phase | Trigger |
|---|---|---|
| `upstream-scout` | scout | a package attr, NixOS/HM option, or flake input schema needs verifying and isn't already established this session |
| `nix-implementer` | implement | facts are in hand; a module/host file needs writing and committing |
| `closure-validator` | validate | a commit could affect an evaluated host/HM config; judges actual vs. expected drift and signs off via `signoff.sh` |
| `fleet-deployer` | deploy | a validated commit needs to reach one or more live hosts |

### Standard pipeline

The pipeline runs four phases in order: scout, implement, validate, deploy.
Implement runs `preflight.sh` before each commit. The main session directs
the pipeline. It dispatches each agent and relays their conclusions.
The main session makes the final call. It does not redo the agent's work.
Trivial doc-only edits change no module, host, or option. These edits skip
the pipeline. Edit and commit these changes directly.

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

A mechanical tier sits below the agent tier. This tier has two Claude Code
hooks. `modules/flake/checks.nix` declares the hooks
(`devenv.shells.default.claude.code.hooks`). Devenv generates the hooks into
`.claude/settings.json` on shell entry. The hooks run deterministically and
use no LLM tokens. The hooks do not judge. Each hook notices a pattern and
nudges the orchestrating session to dispatch the right judgment agent.

| Hook | Event | Enforces |
|---|---|---|
| `hook-commit-reminder.sh` | `PostToolUse(Bash)` | after a `git commit` whose files match `^(modules\|hosts\|profiles\|flake\.(nix\|lock))`, exits 2 with a stderr reminder to dispatch `closure-validator` before deploy/push |
| `hook-push-guard.sh` | `PreToolUse(Bash)` | before a `git push`, requires every outgoing commit touching evaluated config to be an ancestor of `.signed_off_through` in `.agents/baseline.json` (read as committed at HEAD); exits 2 and blocks otherwise |

`hook-commit-reminder.sh` fires only on an actual `git commit` match. This
hook cannot block the commit. `PostToolUse` exit 2 is non-blocking. The
commit already happened before the hook runs.

`hook-push-guard.sh` fails open on several errors. A missing `jq` triggers
exit 0. Any git probing failure triggers exit 0. An unresolvable or empty
range triggers exit 0. A `signed_off_through` value that names a sha absent
from the repo triggers exit 0.

The hook blocks in exactly two cases. Case one: a config commit that is
provably not covered by the sign-off. Case two: `baseline.json` is absent or
malformed at HEAD.

Case two blocks by deliberate choice. It does not fail open. Absence of the
record is exactly the condition the hook gates. Failing open in this case
would let `rm` defeat the gate.

Neither hook re-implements judgment owned by `closure-validator`. Each hook
only detects the precondition for dispatching that agent. The guard binds
the agent, not the human. A push from a plain terminal bypasses the guard
entirely.
