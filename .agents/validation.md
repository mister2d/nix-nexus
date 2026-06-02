# .agents/validation.md — Closure-Diff Baseline and Sign-Off

> **When to use this document.**
> 1. **Before Phase A begins** — capture the pre-refactor baseline.
> 2. **After each group commit in Phase A** — verify per-group closure invariance.
> 3. **After Phase B commit** — verify option rename produces no derivation change.
> 4. **After Phase C commit** — verify builder restructure produces no derivation change.
> 5. **Final sign-off** — confirm all hosts pass before the PR is merged.
>
> Validation is not a gate you visit once at the end. It brackets every
> commit that could affect a host's evaluated configuration.

---

## 1. Hosts and configs under validation

| Target | Build path | Channel |
|---|---|---|
| `sweet16` (NixOS) | `.#nixosConfigurations.sweet16.config.system.build.toplevel` | nixpkgs 25.11 |
| `petunia` (NixOS) | `.#nixosConfigurations.petunia.config.system.build.toplevel` | nixpkgs-unstable |
| `avina` (NixOS) | `.#nixosConfigurations.avina.config.system.build.toplevel` | nixpkgs 25.11 |
| `hermes` (NixOS) | `.#nixosConfigurations.hermes.config.system.build.toplevel` | nixpkgs 25.11 |
| `openclaw` (NixOS) | `.#nixosConfigurations.openclaw.config.system.build.toplevel` | nixpkgs 25.11 |
| `groot@dualie` (HM) | `.#homeConfigurations."groot@dualie".activationPackage` | nixpkgs 25.11 |
| `groot@forge` (HM) | `.#homeConfigurations."groot@forge".activationPackage` | nixpkgs 25.11 |
| `groot@rk3588` (HM) | `.#homeConfigurations."groot@rk3588".activationPackage` | nixpkgs 25.11 (aarch64) |

> **Note on petunia:** petunia uses `nixpkgs-unstable`. Its derivation hash
> can drift between evaluations if the locked unstable commit is updated
> independently of this refactor. Never update `flake.lock` during this
> refactor. Any petunia hash difference must be investigated before acceptance.

---

## 2. Baseline capture procedure

Run this **before any file is edited** for the current phase.

```bash
#!/usr/bin/env bash
# Save as: .agents/scripts/capture-baseline.sh
# Usage: bash .agents/scripts/capture-baseline.sh <phase-label>
# Example: bash .agents/scripts/capture-baseline.sh phase-A

PHASE="${1:-unknown}"
OUTFILE=".agents/SIGNOFF.md"

echo "" >> "$OUTFILE"
echo "## Baseline: $PHASE ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> "$OUTFILE"
echo "" >> "$OUTFILE"
echo "| Host | Derivation hash |" >> "$OUTFILE"
echo "|---|---|" >> "$OUTFILE"

NIXOS_HOSTS="sweet16 petunia avina hermes openclaw"
for host in $NIXOS_HOSTS; do
  hash=$(nix derivation show \
    ".#nixosConfigurations.${host}.config.system.build.toplevel" 2>/dev/null \
    | sha256sum | cut -d' ' -f1)
  echo "| ${host} (NixOS) | \`${hash}\` |" >> "$OUTFILE"
  echo "Captured: ${host} = ${hash}"
done

HM_HOSTS='groot@dualie groot@forge groot@rk3588'
for cfg in $HM_HOSTS; do
  hash=$(nix derivation show \
    ".#homeConfigurations.\"${cfg}\".activationPackage" 2>/dev/null \
    | sha256sum | cut -d' ' -f1)
  echo "| ${cfg} (HM) | \`${hash}\` |" >> "$OUTFILE"
  echo "Captured: ${cfg} = ${hash}"
done

echo "" >> "$OUTFILE"
echo "Git commit at baseline: $(git rev-parse HEAD)" >> "$OUTFILE"
echo "" >> "$OUTFILE"
echo "Baseline written to $OUTFILE"
```

If a host fails to evaluate (`nix derivation show` exits non-zero), record
`EVAL_FAILURE` in the hash column and investigate before proceeding. A host
that does not evaluate before the refactor is a pre-existing issue; document
it explicitly.

---

## 3. Per-commit sign-off procedure

After each group commit or phase commit, run the affected hosts only.

```bash
#!/usr/bin/env bash
# Save as: .agents/scripts/verify-hosts.sh
# Usage: bash .agents/scripts/verify-hosts.sh <phase-label> <host1> [host2 ...]
# Example: bash .agents/scripts/verify-hosts.sh "phase-A-group-1" sweet16 petunia

PHASE="${1:-unknown}"
shift
HOSTS=("$@")
OUTFILE=".agents/SIGNOFF.md"
BASELINE_SECTION="phase-A"  # adjust per invocation

echo "" >> "$OUTFILE"
echo "### Verification: $PHASE ($(date -u +%Y-%m-%dT%H:%M:%SZ))" >> "$OUTFILE"
echo "" >> "$OUTFILE"
echo "| Host | Baseline hash | Post-commit hash | Result |" >> "$OUTFILE"
echo "|---|---|---|---|" >> "$OUTFILE"

for host in "${HOSTS[@]}"; do
  # Determine build path
  if [[ "$host" == *"@"* ]]; then
    build_path=".#homeConfigurations.\"${host}\".activationPackage"
  else
    build_path=".#nixosConfigurations.${host}.config.system.build.toplevel"
  fi

  new_hash=$(nix derivation show "$build_path" 2>/dev/null \
    | sha256sum | cut -d' ' -f1)

  # Read baseline from SIGNOFF.md (grep for the host line in baseline section)
  baseline_hash=$(grep "${host}" "$OUTFILE" \
    | grep -v "Verification" \
    | head -1 \
    | grep -oP '`\K[a-f0-9]{64}')

  if [[ "$new_hash" == "$baseline_hash" ]]; then
    result="✓ PASS"
  elif [[ -z "$baseline_hash" ]]; then
    result="⚠ NO BASELINE — capture baseline first"
  else
    result="✗ DRIFT — investigate before merge"
  fi

  echo "| $host | \`${baseline_hash:-missing}\` | \`${new_hash}\` | $result |" >> "$OUTFILE"
  echo "$host: $result"
done
```

A `DRIFT` result must be explained. Acceptable explanations:

- `services-matrix` avina drift on Phase A group 5: the evaluated config is
  semantically identical; drift is caused by `{ _type = "merge"; }` wrapper
  changing the `nixosSystem` module list structure. In this case, run a
  content-level diff (§4) to confirm no rendered unit or package change.
- Any other drift: **stop, investigate, do not merge**.

---

## 4. Content-level diff (use when a hash differs)

A derivation hash change does not always mean rendered output changed. Use
`nix-diff` or manual inspection to confirm:

```bash
# Build both derivations (pre and post)
pre=$(nix build --no-link --print-out-paths \
  .#nixosConfigurations.avina.config.system.build.toplevel \
  --override-input nixpkgs nixpkgs 2>/dev/null)  # example; adjust as needed

# Or use nix derivation show to inspect the drv structure directly
nix derivation show .#nixosConfigurations.avina.config.system.build.toplevel \
  | python3 -m json.tool > /tmp/post.drv.json

# Diff against a saved pre-commit drv
diff /tmp/pre.drv.json /tmp/post.drv.json
```

For the `deferredModule` type change specifically: if the only diff is in
the Nix module system's internal representation (the `{ _type = "merge"; }`
wrapper), and the rendered `/etc` configuration, systemd units, and package
closure are identical, the drift is acceptable. Document it in SIGNOFF.md.

---

## 5. SIGNOFF.md format

`.agents/SIGNOFF.md` accumulates sign-off entries across all phases.
Each entry follows this format:

```markdown
## Baseline: phase-A (2026-06-01T12:00:00Z)

| Host | Derivation hash |
|---|---|
| sweet16 (NixOS) | `abc123...` |
| petunia (NixOS) | `def456...` |
| avina (NixOS)   | `789abc...` |
| hermes (NixOS)  | `...` |
| openclaw (NixOS)| `...` |
| groot@dualie (HM)  | `...` |
| groot@forge (HM)   | `...` |
| groot@rk3588 (HM)  | `...` |

Git commit at baseline: <sha>

### Verification: phase-A-group-1 development-default (2026-06-01T12:30:00Z)

| Host | Baseline hash | Post-commit hash | Result |
|---|---|---|---|
| sweet16 (NixOS) | `abc123...` | `abc123...` | ✓ PASS |
| petunia (NixOS) | `def456...` | `def456...` | ✓ PASS |

### Verification: phase-A-group-2 desktop-default (...)
...

## FINAL SIGN-OFF — phase-C complete

All 6 NixOS hosts and 3 HM configs: PASS
Reviewer: <name>
Date: <date>
```

---

## 6. Final sign-off checklist

Before closing the PR:

- [ ] `.agents/SIGNOFF.md` has passing entries for all 9 configs.
- [ ] Every `DRIFT` entry has a written justification and content-level
      diff confirming no rendered output change.
- [ ] `nix flake check` green on the final commit.
- [ ] Pre-commit (nixfmt-rfc-style, deadnix, statix) green on the final commit.
- [ ] Root `AGENTS.md` §6 Definition of Done is fully checked.
