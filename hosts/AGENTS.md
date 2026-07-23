# hosts/AGENTS.md — Phase 3: Host Collapse

> **When to read this.** After Phase 2 exit criteria pass and
> `.refactor/module-map.tsv` is complete.
>
> **Goal.** Rewrite each of the 6 NixOS hosts and 3 HM configs so they are thin
> aggregations of `flake.modules.*` **names**, removing all inline cross-cutting
> wiring (buildFixes/allowUnfree, the HM block, host overlays). After this phase
> no `nixpkgs.lib.nixosSystem` / `homeManagerConfiguration` call remains
> hand-written in the tree.
>
> **Authority.** Dendritic host-configuration idiom (§0 root) — how hosts
> consume `flake.modules.nixos.*` and declare `nixosConfigurations` from within
> a flake module. Re-read it before starting.
>
> **Gate B is live this phase.** Every host gets a per-host closure-diff
> sign-off (`validation/AGENTS.md` §3–4) before its commit is considered done.

---

## 1. Order of operations (one host at a time)

Convert in ascending risk so problems surface on the simplest host first:

1. `avina` — adds the Matrix `pkgs-stable` overlay.
2. `hermes` — adds `llm-agents` + `mcp` overlays and inline `unstablePkgs`.
3. `sweet16` — nixos-hardware stack, `ddukes` HM.
4. `petunia` — **unstable channel**, disko, `home-manager-unstable`.
5. Then the 3 standalone HM configs (`groot@dualie`, `groot@rk3588`,
   `groot@forge`).

**One host per commit. One sign-off per commit.** Never batch.

---

## 2. The collapse pattern

Hosts move into a flake module that declares `nixosConfigurations`. The inline
modules from today's `flake.nix` become references to named dendritic modules.

### Before (today's `sweet16`, abridged)
```nix
sweet16 = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit inputs self; };
  modules = [
    (_: { nixpkgs.overlays = [ self.overlays.buildFixes ]; nixpkgs.config.allowUnfree = true; })
    nixos-hardware.nixosModules.lenovo-thinkpad-z
    nixos-hardware.nixosModules.common-cpu-amd
    nixos-hardware.nixosModules.common-gpu-amd
    nixos-hardware.nixosModules.common-pc-ssd
    ./hosts/sweet16/default.nix
    home-manager.nixosModules.home-manager
    { home-manager = { /* ddukes block */ }; }
  ];
};
```

### After (dendritic — validate exact attr paths against the authority)
```nix
{ inputs, ... }:
{
  flake.nixosConfigurations.sweet16 = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; inherit (inputs) self; };   # see §4 on self
    modules = [
      inputs.self.modules.nixos.overlays-global        # buildFixes + allowUnfree (named module)
      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z
      inputs.nixos-hardware.nixosModules.common-cpu-amd
      inputs.nixos-hardware.nixosModules.common-gpu-amd
      inputs.nixos-hardware.nixosModules.common-pc-ssd
      inputs.self.modules.nixos.host-sweet16           # the converted hosts/sweet16/default.nix
      inputs.self.modules.nixos.home-manager-ddukes    # the named HM wiring module
    ];
  };
}
```

Key moves:
- The inline `buildFixes`+`allowUnfree` module becomes **one** named module
  (`overlays-global` or similar) referenced by every host. This is where the
  per-host duplication is finally eliminated — and where you prove (Gate B) the
  single setter reproduces each host's closure.
- `hosts/<h>/default.nix` is itself converted to `flake.modules.nixos.host-<h>`
  (it was deferred from Phase 2 because it is a host entry point; convert it now,
  preserving its `imports` of profiles/modules — rewired to named modules).
- The repeated `home-manager.nixosModules.home-manager` + user block becomes
  named HM-wiring modules: one for `ddukes`, one for `groot` (they diverge —
  keep them distinct).

---

## 3. Per-host specifics (verified — do not generalize away)

- **`petunia`** uses `inputs.nixpkgs-unstable.lib.nixosSystem` and
  `inputs.home-manager-unstable`. Preserve the unstable builder and unstable HM
  wiring as a distinct named module; do **not** unify it with the stable HM
  module. The `disko` nixosModule stays as an input-provided module in the
  list. GPU/ROCm wiring is inlined in `modules/hardware/petunia/rdna4.nix`.
- **`avina`** has the inline Matrix overlay pinning 7 packages
  (`matrix-synapse-unwrapped`, `matrix-authentication-service`, `livekit`,
  `lk-jwt-service`, `element-web`, `element-call`, `postgresql_16`) from
  `pkgs-stable`. Convert this to a named module
  (`flake.modules.nixos.matrix-pin-stable`) and reference it only from `avina`.
  The overlay body is unchanged; closure-diff must show the same 7 pins.
- **`hermes`** has two host overlays: the `mcp` overlay (already a
  `flake.overlays.mcp` after Phase 1 — reference it) and the inline
  `llm-agents`/`hermes-agent` override. Convert the latter to a named module
  preserving the `overridePythonAttrs`/`makeWrapperArgs` body verbatim — that
  PYTHONPATH wrapper is load-bearing. The inline `unstablePkgs` import in the HM
  block also stays verbatim.
- **`hermes` HM** uses the `groot` user with an inline `imports` list of
  `modules/user/{bash,terminal-home,neovim-home}.nix` + the host `home.nix`.
  Those module files are now named (Phase 2) — reference them by name; the
  host `home.nix` becomes `flake.modules.homeManager.home-<host>`.

---

## 4. The `self` migration (final resolution)

Phase 2 kept `self`-consuming leaves working via threaded `inputs.self`. In
Phase 3, the `nixosSystem` calls drop `specialArgs.self` only if every consumer
now receives it through the module system. Before removing `self` from any
host's `specialArgs`, grep the host's transitive module closure for `self`
usage and confirm each hit resolves via `inputs.self`. The six known consumers
(root `AGENTS.md` §2) are the minimum checklist; do not assume they are the
only ones — re-grep.

---

## 5. Per-host completion loop

For each host, in the §1 order:
1. Convert `hosts/<h>/default.nix` → `flake.modules.nixos.host-<h>`, rewiring
   its `imports` to named modules from `module-map.tsv`.
2. Convert the host's HM block + `home.nix` → named HM module(s).
3. Convert any host overlay → named module (§3).
4. Add `flake.nixosConfigurations.<h>` (or `flake.homeConfigurations.<c>`) with
   the thin module list; remove the corresponding hand-written block from the
   old `flake.nix` location.
5. `pre-commit run --files <changed>` → `nix flake check`.
6. **Gate B sign-off** (`validation/AGENTS.md` §3–4): regenerate the host `.drv`,
   diff against baseline, account for every delta (the only expected delta is
   from `allowUnfree`/overlay dedup — prove it is a no-op), run the `pkgs-*`
   pin check, append the sign-off block.
7. Commit only after the sign-off block is `PASS` or fully-justified
   `PASS-WITH-DELTA`.

---

## 6. Phase 3 exit criteria

- [ ] All 6 `nixosConfigurations` and 3 `homeConfigurations` declared via
      `flake.*` from dendritic modules; zero hand-written builder calls remain.
- [ ] All inline cross-cutting wiring (buildFixes/allowUnfree, HM block, host
      overlays) replaced by named-module references; per-host duplication gone.
- [ ] `allowUnfree` reduced to a single authoritative setter with closure proof.
- [ ] `petunia` still on the unstable channel + unstable HM; `avina` Matrix pins
      intact; `hermes` PYTHONPATH wrapper intact.
- [ ] `.refactor/SIGNOFF.md` holds a passing block for **all 9** configs.
- [ ] `pkgs-*` pin check `unchanged` for every host.
- [ ] `nix flake check` green; pre-commit green.

When every box is checked, return to the root `AGENTS.md` §6 Definition of Done
and confirm the full set. The repo's long-standing "dendritic" claim is now
accurate.
