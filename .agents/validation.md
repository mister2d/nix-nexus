# .agents/validation.md — closure-diff and deploy toolbox

The authoritative validation method for nix-nexus is the script toolbox in
`.agents/scripts/`. Scripts encode every deterministic step (clean per-rev
evals, drift comparison, consumer analysis, lock diffing, lint gates,
timed builds, remote deploys, generation checks); agents and the main
session interpret their output and make judgment calls (see `AGENTS.md` §12).

All closure comparisons use clean `git+file:$PWD?rev=<rev>#...` evaluations
of a committed rev — never the dirty working tree. `groot@rk3588` (aarch64)
is reported `N/A` on non-aarch64 hosts, not as a failure.

## Toolbox

| Script | Purpose | Exit codes |
|---|---|---|
| `lib.sh` | shared fleet lists (`NIXOS_HOSTS`, `HM_CONFIGS`) and `drv_at_rev` clean-eval helper; sourced only | n/a |
| `capture-baseline.sh <label> [rev]` | records per-config drv paths at a rev; appends a block to `SIGNOFF.md` (or `--outfile`/`OUTFILE`) | 0 |
| `verify-drift.sh <base-rev> [new-rev]` | per-config drv comparison between two revs; markdown table on stdout | 0 no drift, 10 drift found |
| `consumers.sh <name>...` | recursively resolves which hosts reach a registry key or flake input; derives the expected-drift set | 0 |
| `lock-diff.sh <old-rev> <new-rev>` | node-by-node `flake.lock` diff via `jq` | 0 no change, 10 nodes changed |
| `preflight.sh <files>...` | `pre-commit run --files` then `nix flake check` | 0 pass, 1 pre-commit fail, 2 flake check fail |
| `cert-check.sh [--min-minutes N]` | validates the ephemeral Vault SSH cert (principal `root`, remaining TTL) | 0 OK, 20 expiring, 21 wrong principal |
| `build-host.sh <host>` | timed local build with substituted-vs-built cache stats | 0 success, 1 build failed |
| `deploy-host.sh <host> [--build-host <h>] [--boot\|--test] [--check-only]` | cert-check → ssh probe → `nixos-rebuild --target-host` → generation verify | 0 success, 1 cert, 2 ssh, 3 rebuild, 4 verify |
| `verify-generation.sh <host> [toplevel]` | via ssh: compares the remote system profile against an expected toplevel | 0 OK/report-only, 1 mismatch |

## Standard drift-verification flow

1. `lock-diff.sh <base> <head>` — what flake inputs actually moved.
2. `consumers.sh <changed-key-or-input>...` — which hosts are expected to drift.
3. `verify-drift.sh <base> <head>` — which hosts actually drifted.
4. Judge: actual drift set ⊆ expected drift set. If they match, sign off in
   `SIGNOFF.md` using the existing entry format (baseline table + verification
   block). If they don't match, root-cause with `nix derivation show | jq`
   before proceeding — never fudge or assume.

## Deploy flow

`cert-check.sh` must pass before any deploy is attempted. All hosts
(including sweet16) deploy remotely via `deploy-host.sh <host>`, which wraps
`nixos-rebuild switch --flake .#<host> --target-host root@<host>.home.lan`.
There is no local-sudo deploy path. `--check-only` runs the cert and ssh
reachability stages without ever invoking `nixos-rebuild` — use it to
validate reachability before a real deploy.

## Mechanical hooks

Wired via `.claude/settings.json`. Deterministic; nudge the orchestrating
session toward the agent pipeline above rather than judging anything
themselves.

| Script | Event | Args | Exit codes |
|---|---|---|---|
| `hook-commit-reminder.sh` | `PostToolUse(Bash)` | stdin: PostToolUse hook JSON (`.tool_input.command`); or `--test <command-string> [--test-rev <rev>]` | 0 not a commit / no evaluated-config files; 2 commit touches `^(modules/\|hosts/\|profiles/\|flake\.(nix\|lock))` (non-blocking on `PostToolUse` — stderr reminder only) |
| `hook-push-guard.sh` | `PreToolUse(Bash)` | stdin: PreToolUse hook JSON (`.tool_input.command`); or `--test <command-string> [--test-range <A..B>]` | 0 not a push, unresolvable range, no evaluated-config drift, or a git probing error (fail-open); 2 evaluated-config commits outgoing without a `.agents/SIGNOFF.md` entry in range (blocking on `PreToolUse`) |

## Historical phase records

`.agents/phase-A.md`, `.agents/phase-B.md`, `.agents/phase-C.md` are records
of the completed dendritic-pattern refactor. They are historical and are not
part of the current validation method.
