# .agents/validation.md — closure-diff and deploy toolbox

The script toolbox in `.agents/scripts/` is the authoritative validation
method for nix-nexus.

The scripts encode every deterministic step. Steps include clean per-rev
evals, drift comparison, consumer analysis, lock diffing, lint gates, timed
builds, remote deploys, and generation checks.

Agents and the main session interpret the script output. They make the
judgment calls. See `AGENTS.md` §12.

All closure comparisons use clean `git+file:$PWD?rev=<rev>#...` evaluations
of a committed rev. They never use the dirty working tree.

`groot@rk3588` (aarch64) reports `N/A` on non-aarch64 hosts. This is not a
failure.

## Sign-off records

There are two artifacts. Each has a different lifetime.

- **`.agents/baseline.json`** — the current state. `signoff.sh` replaces it
  on every sign-off. It holds `signed_off_through` (the validated rev) and
  one entry per config. Each entry holds its full `/nix/store/…drv` path and
  a status of `ok` or `na`. This is the only place full drv paths live.
  There is no history array. `git log -p .agents/baseline.json` gives that
  history. The history cannot drift.
- **`.agents/signoff/<date>-<slug>.md`** — one immutable entry per sign-off.
  `signoff.sh` generates it. Everything above `## Judgment` is
  machine-written. The judgment prose below it is the agent's own text.

`signoff.sh` is the only writer of both artifacts. Hand-authored entries
caused the old `SIGNOFF.md` to accumulate four incompatible formats.

## Toolbox

| Script | Purpose | Exit codes |
|---|---|---|
| `lib.sh` | shared fleet lists (`NIXOS_HOSTS`, `HM_CONFIGS`) and `drv_at_rev` clean-eval helper. Sourced only | n/a |
| `signoff.sh --slug <s> [--title "<text>"] [--base REV] [--head REV] [--verdict blocked] [--dry-run]` (judgment on stdin), or `signoff.sh --bootstrap` | the only sign-off writer: generates `.agents/signoff/<date>-<slug>.md` and replaces `.agents/baseline.json` | 0 wrote, 2 args, 3 dirty tree, 4 empty stdin, 5 entry exists, 10 eval failure |
| `verify-drift.sh <base-rev> [new-rev]` | per-config drv comparison between two revs. Prints a markdown table on stdout | 0 no drift, 10 drift found |
| `consumers.sh <name>...` | recursively resolves which hosts reach a registry key or flake input. Derives the expected-drift set | 0 |
| `lock-diff.sh <old-rev> <new-rev>` | node-by-node `flake.lock` diff via `jq` | 0 no change, 10 nodes changed |
| `preflight.sh <files>...` | `nix develop --impure --command prek run --files` then `nix flake check --impure` (the runner is `prek`. `pre-commit` is not installed) | 0 pass, 1 lint fail, 2 flake check fail, 3 arg error |
| `cert-check.sh [--min-minutes N] [--cert PATH]` (also settable via `$SSH_CERT`) | validates the ephemeral Vault SSH cert (principal `root`, remaining TTL) | 0 OK, 20 expiring, 21 wrong principal |
| `build-host.sh <host>` | timed local build with substituted-vs-built cache stats | 0 success, 1 build failed |
| `deploy-host.sh <host> [--build-host <h>] [--boot\|--test] [--check-only]` | cert-check → ssh probe → `nixos-rebuild --target-host` → generation verify | 0 success, 1 cert, 2 ssh, 3 rebuild, 4 verify |
| `verify-generation.sh <host> [toplevel]` | via ssh: compares the remote system profile against an expected toplevel | 0 OK/report-only, 1 mismatch |

## Standard drift-verification flow

1. `lock-diff.sh <base> <head>` shows which flake inputs moved.
2. `consumers.sh <changed-key-or-input>...` shows which hosts should drift.
3. `verify-drift.sh <base> <head>` shows which hosts actually drifted.
4. Compare the actual drift set against the expected drift set.

   If the sets match, record it with `signoff.sh --slug <kebab>`. Supply
   judgment prose on stdin. The script generates every fact: revs, commit
   list, drift table, and hashes. It replaces `.agents/baseline.json`. Never
   hand-author an entry. Never type a store hash by hand.

   If the sets do not match, root-cause it with `nix derivation show | jq`
   before you proceed. Never guess or assume. `--verdict blocked` records
   the investigation without advancing the baseline.

## Deploy flow

`cert-check.sh` must pass before any deploy attempt. All hosts, including
sweet16, deploy remotely through `deploy-host.sh <host>`. This script wraps
`nixos-rebuild switch --flake .#<host> --target-host root@<host>.home.lan`.
There is no local-sudo deploy path. `--check-only` runs only the cert and
ssh reachability stages. It never invokes `nixos-rebuild`. Use it to
validate reachability before a real deploy.

## Mechanical hooks

`modules/flake/checks.nix` declares the hooks under devenv's
`claude.code.hooks`. Devenv generates `.claude/settings.json` from them on
devenv shell entry. The hooks are deterministic. They nudge the
orchestrating session toward the agent pipeline above. They never judge
anything themselves.

| Script | Event | Args | Exit codes |
|---|---|---|---|
| `hook-commit-reminder.sh` | `PostToolUse(Bash)` | stdin: PostToolUse hook JSON (`.tool_input.command`), or `--test <command-string> [--test-rev <rev>]` | 0 not a commit / no evaluated-config files · 2 commit touches `^(modules/\|hosts/\|profiles/\|flake\.(nix\|lock))` (non-blocking on `PostToolUse`, stderr reminder only) |
| `hook-push-guard.sh` | `PreToolUse(Bash)` | stdin: PreToolUse hook JSON (`.tool_input.command`), or `--test <command-string> [--test-range <A..B>] [--test-through <sha>]` | 0 not a push, unresolvable/empty range, no config commits outgoing, or any git/jq error (fail-open) · 2 `baseline.json` absent or malformed at HEAD, or ≥1 outgoing config commit not an ancestor of `.signed_off_through` · 3 bad arguments |

## Historical phase records

`.agents/phase-A.md`, `.agents/phase-B.md`, and `.agents/phase-C.md` record
the completed dendritic-pattern refactor. They are historical. They are not
part of the current validation method.

`.agents/signoff-archive.md` (formerly `SIGNOFF.md`) holds 44 sign-off
entries. Sign-off authors hand-wrote them between 2026-06-02 and 2026-08-13.
The file closed on 2026-08-13. Nothing appends to it. Its header indexes the
eight entries with real investigative detail. The file keeps the text
verbatim, including references to the file's old path. Like the phase
records, nobody edits historical prose to match the current layout.
