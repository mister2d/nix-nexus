# modules/AGENTS.md — Phase 2: Leaf Module Conversion

> **When to read this.** After Phase 1 exit criteria pass.
>
> **Goal.** Convert every leaf `.nix` configuration file into a dendritic
> flake-parts module that contributes to `flake.modules.nixos.<name>` or
> `flake.modules.homeManager.<name>`. After this phase no file is a
> path-imported "plain" module. **Hosts are not touched yet** — they still
> import old paths and must keep building identically until Phase 3.
>
> **Authority.** Dendritic file-as-module convention (§0 root). Re-read its
> `flake.modules` section before starting.

---

## 1. The conversion, concretely

### Before (current nix-nexus leaf — e.g. `modules/core/users.nix`)
```nix
{ pkgs, ... }:
{
  users.users.ddukes = { /* … */ };
}
```

### After (dendritic flake module)
```nix
# The outer function takes flake-parts module args (inputs, lib, withSystem, …).
# It registers a NixOS module under a stable name in the flake.modules namespace.
{ ... }:
{
  flake.modules.nixos.core-users = { pkgs, ... }: {
    users.users.ddukes = { /* …unchanged body… */ };
  };
}
```

The **inner** module keeps the original `{ pkgs, ... }: { … }` body **verbatim**.
The conversion is purely the outer wrapping + name registration. Do not
"improve" the body during conversion — body changes are separate, individually
closure-justified commits.

---

## 2. Namespace and naming rules

- NixOS system modules → `flake.modules.nixos.<name>`.
- Home-manager modules (the `*-home.nix` files and `modules/user/*`) →
  `flake.modules.homeManager.<name>`.
- **Name = stable identifier hosts will reference in Phase 3.** Derive it from
  the path, kebab-cased, deduped: `modules/core/users.nix` → `core-users`;
  `modules/desktop/niri-home.nix` → `niri` under the `homeManager` namespace;
  `modules/services/matrix/synapse.nix` → `matrix-synapse`.
- Record every `path → namespace.name` mapping in
  `.refactor/module-map.tsv` as you go. Phase 3 consumes this map. A host that
  can't find a module name is a Phase-3 blocker rooted in a missing map entry.

---

## 3. Known hazards in this tree (verified — handle explicitly)

### 3a. `self` consumers
Six files read `self` today: `modules/programs/dev.nix`,
`modules/programs/custom-scripts.nix`, `modules/user/dev-home.nix`,
`modules/services/matrix/{haproxy,synapse,element}.nix`. After conversion the
inner module no longer receives `self` via `specialArgs`. Provide it through the
flake-parts arg as `inputs.self` (captured by the outer function) and threaded
into the inner module, **or** via `_module.args` if the dendritic authority
prescribes that. Verify which, then apply uniformly. Each of these six files
gets an explicit note in the Phase 2 report confirming `self` still resolves.

### 3b. `inputs.<pkgs-*>` instantiation inside leaves
`modules/user/dev-home.nix` and `modules/user/home.nix` call
`import inputs.pkgs-terraform { … }` etc. directly. The outer dendritic function
receives `inputs`; thread it to the inner module unchanged. **Do not** refactor
these into overlays in Phase 2 — that would change closures. Preserve the
direct-import pattern exactly; only the arg plumbing changes.

### 3c. `*-home.nix` vs system modules sharing a directory
`modules/desktop/` mixes system modules (`niri.nix`, `sway.nix`) and HM modules
(`niri-home.nix`, `sway-home.nix`, `waybar-home.nix`). Route each to the correct
namespace by role, not by directory. The `-home` suffix is the signal;
confirm by reading the body (system modules set NixOS options like
`programs.niri.enable` at system scope; HM modules set `programs.niri.settings`
/ `home.packages`).

### 3d. Overlay-bearing leaves
`modules/desktop/niri.nix` defines an inline `nixpkgs.overlays` entry
(niri `doCheck=false`). That stays inside the converted module body — it is a
NixOS-option assignment, not a flake overlay. Do not hoist it to
`flake.overlays`.

### 3e. Files that are NOT flake modules
`modules/programs/openclaude-lock.json` and any generated lock/JSON are data,
not modules — exclude from `import-tree` discovery. `hardware-configuration.nix`,
`disko.nix`, and install scripts under `hosts/` are handled in Phase 3, not here.

---

## 4. Profiles are aggregator modules

`profiles/*/default.nix` are pure `imports = [ ../../modules/... ]` aggregators
(verified: `profiles/server` imports `security`, `sysctl`, `users` and sets
`allowUnfree`). Convert each profile to a dendritic module that **composes named
modules** rather than paths:

```nix
{ ... }:
{
  flake.modules.nixos.profile-server = { ... }: {
    imports = [
      # reference sibling dendritic modules by the config they contribute,
      # per the dendritic authority's composition idiom — NOT relative paths
    ];
    nixpkgs.config.allowUnfree = true;          # reconcile with §3e dedup, see below
    # …unchanged settings body…
  };
}
```

**`allowUnfree` reconciliation.** It is set in `profiles/server`,
`profiles/workstation`, *and* the per-host inline module. After Phase 3 the
per-host inline copy disappears. In Phase 2, leave the profile copies in place
(removing one now could change a host closure that still relies on the inline
one). Track the duplication in the Phase 2 report; resolve it in Phase 3 with
closure proof that the single remaining setter is sufficient.

---

## 5. Per-file loop (apply to every leaf)

1. Read the file. Identify role (nixos vs homeManager) from the body.
2. Wrap: outer dendritic function → `flake.modules.<ns>.<name>` → inner body
   verbatim.
3. Thread `inputs`/`self` if the body uses them (§3a, §3b).
4. Append `path<TAB>ns.name` to `.refactor/module-map.tsv`.
5. `nix develop --command pre-commit run --files <file>` then `nix flake check`.
6. Commit one logical group at a time (e.g. all of `modules/core` in one commit
   is acceptable since hosts aren't rewired yet; never mix nixos+homeManager
   namespaces carelessly).

---

## 6. Phase 2 exit criteria

- [ ] Every leaf `.nix` (excluding §3e data/host files) is a
      `flake.modules.{nixos,homeManager}.<name>` contributor.
- [ ] `.refactor/module-map.tsv` is complete and covers every converted file.
- [ ] The six `self`-consumers verified resolving `self` post-conversion.
- [ ] `pkgs-*` direct-import leaves unchanged in behaviour (§3b).
- [ ] `nix flake check` green; pre-commit green.
- [ ] **Closure invariant:** because hosts still import old paths *and* the new
      flake.modules now exist, confirm hosts have **not** drifted —
      `sweet16`/`avina` `.drv` still identical to baseline. (If `import-tree`
      now auto-applies a module that a host didn't previously get, you'll see
      drift here. That is the signal that a converted module is being globally
      applied when it should be opt-in — fix before Phase 3.)

> **Watch for global-application drift.** The dendritic/`import-tree` model
> evaluates every discovered module. A leaf that sets system options
> *unconditionally* (not behind an `flake.modules` name that a host opts into)
> will apply everywhere. Ensure each converted leaf only *registers* a named
> module and does not also assign config at top level. This is the most common
> way Phase 2 silently changes every host's closure.

Only when every box is checked: proceed to `hosts/AGENTS.md`.
