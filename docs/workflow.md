# Development workflow

A day-one guide to changing something in nix-nexus and getting it onto a
machine. It assumes you can use git and a terminal, and that you know little or
no Nix. You do not need to understand the dendritic pattern to follow this —
read [architecture.md](./architecture.md) when you want to know *why* it is
shaped this way.

If you read nothing else, read [the loop at a glance](#the-loop-at-a-glance)
and [when something goes wrong](#when-something-goes-wrong).

---

## The mental model

Three different things in this repo are all "Nix", and conflating them is the
most common source of early confusion. They are separate layers:

| Layer | What it configures | Where it lives | Applied by |
|---|---|---|---|
| **Dev shell** | *Your tools while working on this repo* — formatters, linters, `sops`, `age` | `modules/flake/checks.nix` | entering the directory (direnv) or `nix develop --impure` |
| **NixOS system** | A whole machine — kernel, services, users, packages | `modules/`, `hosts/`, `profiles/` | `deploy-host.sh <host>` |
| **Home Manager** | One user's environment — shell config, aliases, dotfiles | same tree, `homeManager` modules | same deploy, or `home-manager switch` on standalone hosts |

The dev shell has nothing to do with the machines you deploy. Changing a linter
in `checks.nix` does not change any host.

### The fleet

Seven configurations. Four are full NixOS machines you deploy to; three are
just a user environment on a machine someone else manages.

| Config | Kind | Notes |
|---|---|---|
| `sweet16` | NixOS | **The workstation you are probably sitting at.** See the warning under [Deploy](#step-6--deploy) |
| `petunia` | NixOS | Inference box. Builds are slow here — build on petunia itself |
| `avina` | NixOS | LXC container |
| `hermes` | NixOS | LXC container |
| `groot@dualie` | Home Manager only | Debian host |
| `groot@forge` | Home Manager only | |
| `groot@rk3588` | Home Manager only | **aarch64** — cannot be evaluated or checked from an x86_64 machine |

### Vocabulary

Enough to read the tool output. Not a Nix course.

| Term | Plain meaning |
|---|---|
| **derivation** (`.drv`) | A build recipe. Nix computes one from your config *before* building anything |
| **closure** | A thing plus everything it depends on, transitively |
| **drift** | The derivation hash changed, so the built result will differ. Expected when you change a package; suspicious after a pure rename |
| **generation** | A numbered snapshot of a machine's system state. You can boot into an older one |
| **flake input** | A pinned external dependency (nixpkgs, home-manager…), locked in `flake.lock` |
| **registry key** | The name a module registers itself under, e.g. `core-tpm2`. Hosts pick modules by name, never by file path |
| **evaluation** | Nix reading your config and computing derivations. Fast-ish, and where most errors surface. Distinct from *building* |

---

## One-time setup

You need Nix with flakes enabled. On a non-NixOS machine see
[non-nixos.md](./non-nixos.md).

```bash
git clone <this repo>
cd nix-nexus
direnv allow          # if you use direnv — recommended
```

With direnv, the dev shell is entered automatically whenever you `cd` in.
Without it, run this yourself every time:

```bash
nix develop --impure
```

**`--impure` is mandatory, not cosmetic.** The dev shell needs to know its own
directory, and it finds that by reading `$PWD` — something Nix refuses to do in
pure mode. Every `nix develop` and `nix flake check` against this repo needs
it. Plain `nix develop` fails with a confusing assertion about not being able
to determine the current directory.

The first entry builds the whole dev shell and can take a few minutes.
Afterwards it is cached and instant.

### Things you must not hand-edit

Entering the shell **generates** several files as symlinks into the read-only
Nix store. Editing them either fails or is silently discarded on the next shell
entry:

| File | Generated from |
|---|---|
| `.pre-commit-config.yaml` | `modules/flake/checks.nix` (`git-hooks.hooks`) |
| `.claude/settings.json` | `modules/flake/checks.nix` (`claude.code`) |
| `.mcp.json` | same |

To change linting or hooks, edit `modules/flake/checks.nix` and re-enter the
shell.

Entering the shell also installs the git pre-commit hook for you. There is no
install command to run.

---

## The loop at a glance

```
  find          consumers.sh <key>            who is affected?
   |
  edit          your editor                   one logical change
   |
  lint          preflight.sh <files>          format + evaluate everything
   |
  commit        git commit                    hooks re-run automatically
   |
  check         verify-drift.sh <base> HEAD   did the right things change?
   |
  sign off      signoff.sh --slug <name>      record the judgment
   |
  deploy        deploy-host.sh <host>         push it to a machine
```

Small doc-only edits skip everything from *check* onward. The full loop is for
changes under `modules/`, `hosts/`, `profiles/`, or `flake.nix` / `flake.lock`
— the paths that actually affect a machine. This guide calls those
**evaluated config**.

---

## Step 1 — Find what to change

There is no central list of modules. Every `.nix` file under `modules/`,
`hosts/`, or `profiles/` is discovered automatically and registers itself under
a name. So the question is usually "which file owns this setting?"

```bash
# Search the tree
grep -rn 'tailscale' modules/ hosts/ profiles/

# List every registry name that exists (39 of them at time of writing)
nix eval --json .#modules.nixos --apply builtins.attrNames | jq
nix eval --json .#modules.homeManager --apply builtins.attrNames | jq

# Which hosts actually use a given module or flake input?
.agents/scripts/consumers.sh core-tpm2
```

`consumers.sh` is the important one. It follows module-to-module references and
tells you which *hosts* end up including a key:

```
sweet16: via hosts/sweet16/default.nix
petunia: via hosts/petunia/default.nix
```

That list is your **expected blast radius**. Write it down — in step 4 you
compare it against what actually changed.

For adding something new rather than editing something existing, the
[cookbook](./cookbook.md) has seven step-by-step recipes (new module, new user,
new host, and so on). Start there.

---

## Step 2 — Make the change

Edit the file. Two rules matter more than the rest:

**One logical change per commit.** Linting and drift-checking are per-commit,
and a commit that does two unrelated things cannot be validated or reverted
cleanly.

**Never import another module by file path.** Modules reference each other by
registry name, through a `nixosModules` / `homeManagerModules` argument:

```nix
# correct
imports = [ nixosModules.core-tpm2 ];

# wrong — breaks the pattern
imports = [ ../../modules/core/tpm2.nix ];
```

If you are adding a brand-new file, **`git add` it before building.** Nix
evaluates the *git-tracked* tree, so an untracked new `.nix` file is silently
ignored — you will build successfully and wonder why nothing changed.

### Don't guess package or option names

Package attributes and option paths drift between nixpkgs releases, so a name
you remember may be renamed or gone. Look it up rather than guessing:

```bash
nix eval --raw nixpkgs#ripgrep.name        # does this attribute exist?
```

Inside an AI session the `nixos-tools` MCP server does this directly. Either
way, verify before writing.

---

## Step 3 — Lint

```bash
.agents/scripts/preflight.sh modules/tools/bash.nix hosts/sweet16/default.nix
```

This runs two gates and stops at the first failure:

1. the formatting/lint hooks on the files you name
2. `nix flake check --impure` — evaluates all seven configurations

Three linters run:

| Linter | Catches |
|---|---|
| `nixfmt` | Formatting. **Rewrites your file in place** |
| `deadnix` | Unused bindings and unused function arguments |
| `statix` | Nix anti-patterns — `{ ... }:` that should be `_:`, `with pkgs;`, and similar |

**When `nixfmt` reformats a file, re-stage it and run again.** That is normal,
not an error. Do not fight the formatter.

> The command is `prek`, not `pre-commit` — `prek` is a faster drop-in
> reimplementation, and `pre-commit` is not installed. Inside an already-entered
> shell you can run `prek run --files <files>` directly. Prefer `preflight.sh`,
> which also runs the flake check and gets `--impure` right.

Then commit normally. The git hook re-runs the linters on staged files.

---

## Step 4 — Check the blast radius

This is the step that distinguishes "it evaluates" from "it does what I meant".
Skip it only for doc-only changes.

```bash
# what flake inputs moved, if any?
.agents/scripts/lock-diff.sh <base-commit> HEAD

# which configs actually changed?
.agents/scripts/verify-drift.sh <base-commit> HEAD
```

`verify-drift.sh` prints a table of all seven configs with `none`, `DRIFT`, or
`N/A`, and exits `10` if anything drifted. Use the last signed-off commit as
your base:

```bash
jq -r .signed_off_through .agents/baseline.json
```

Now compare against the expected set from step 1:

| Situation | Meaning |
|---|---|
| Drift matches the `consumers.sh` list | Good. Proceed |
| A host drifted that shouldn't have | Stop and investigate — something is coupled in a way you didn't expect |
| Nothing drifted after a real change | Suspicious. Did you `git add` the file? |
| Pure rename/move produced drift | Stop. A structural refactor should change nothing |
| `groot@rk3588` shows `N/A` | Normal on x86_64. It is aarch64 and cannot be evaluated here |

To investigate unexpected drift, diff the two derivations:

```bash
diff <(nix derivation show /nix/store/...-A.drv | jq -S .) \
     <(nix derivation show /nix/store/...-B.drv | jq -S .)
```

---

## Step 5 — Sign off

Every change to evaluated config needs a recorded judgment before it can be
pushed. This is enforced — see [when something goes wrong](#the-push-guard-blocked-my-push).

```bash
.agents/scripts/signoff.sh --slug tailscale-exit-node <<'EOF'
### Expected-drift set

sweet16 and petunia — the only consumers of `core-tailscale`
(from `consumers.sh`).

### Actual vs expected

Equal. verify-drift reports DRIFT on exactly those two, `none` elsewhere.
EOF
```

You supply **only the prose**. The script generates the filename, timestamp,
commit list, drift table, every store hash, and the verdict header, then writes:

- `.agents/signoff/<date>-<slug>.md` — one immutable entry per sign-off
- `.agents/baseline.json` — current state, replaced each time

Never type a store hash into a sign-off. If you find yourself doing that, the
script should be doing it instead.

Use these headings: `### Expected-drift set` and `### Actual vs expected`
always; add `### Root cause` when they differ and `### Deploy note` when you
deployed something.

If the drift does **not** match expectations, do not sign off. Record the
investigation without advancing the baseline:

```bash
.agents/scripts/signoff.sh --slug weird-drift --verdict blocked <<'EOF'
...
EOF
```

Then commit the sign-off — it is a normal commit, conventionally its own:

```bash
git add .agents && git commit -m "docs(signoff): record tailscale exit node drift"
```

---

## Step 6 — Deploy

> **`sweet16` is very likely the machine you are sitting at.** A `switch`
> restarts user services and can disturb a running desktop session. For
> compositor, shell, or theming changes use `--boot` so they apply at the next
> boot, and let the user reboot on their own schedule.

Deploys are always remote, even to the local machine, and always authenticate
with a short-lived Vault-issued SSH certificate. There is no local-sudo path.

```bash
# check the cert and reachability without touching the machine
.agents/scripts/deploy-host.sh sweet16 --check-only

# the real thing
.agents/scripts/deploy-host.sh sweet16

# apply at next boot instead of immediately
.agents/scripts/deploy-host.sh sweet16 --boot

# build on the target instead of locally — use this for petunia,
# whose kernel is already cached there and slow to rebuild here
.agents/scripts/deploy-host.sh petunia --build-host petunia.home.lan
```

The script runs four stages and stops at the first failure: certificate check,
ssh reachability, `nixos-rebuild`, then a generation check confirming the
machine is actually running what you built.

To time a build without deploying:

```bash
.agents/scripts/build-host.sh sweet16
```

### Before your first deploy

You need an SSH certificate at `~/.ssh/id_ed25519-cert.pub`, signed by the CA
in `certs/trusted_ssh_ca.pub`, with principal `root` and more than 30 minutes
of validity left. Check it:

```bash
.agents/scripts/cert-check.sh
```

**Obtaining and refreshing that certificate is a manual step and the command is
not stored in this repo — ask the maintainer.** Renewal is deliberately not
automated. `cert-check.sh` will tell you when it is expiring; it will not fix
it for you, and neither will the deploy script.

### Standalone Home Manager hosts

`dualie`, `forge`, and `rk3588` are not deployed by these scripts. They
self-manage — run this on the host itself:

```bash
home-manager switch --flake .#groot@dualie
```

---

## When something goes wrong

### The push guard blocked my push

```
push blocked — config commits not covered by the latest sign-off
(signed off through 8af2830):
  6c83f42 fix(tools): fix lrt alias
```

You changed evaluated config and have not signed off on it. This is working as
intended. Go do [step 5](#step-5--sign-off), commit the sign-off, and push again.

The guard requires every outgoing commit touching `modules/`, `hosts/`,
`profiles/` or `flake.*` to be an ancestor of `signed_off_through` in
`.agents/baseline.json`. Merely having *a* sign-off in the range is not enough —
it has to actually cover your commits. A sign-off written for an earlier commit
will not do.

This hook only runs inside an AI coding session. It is a safety net for
automation, not a lock on you.

### `nix develop` fails with an assertion about the current directory

You forgot `--impure`. See [one-time setup](#one-time-setup).

### `pre-commit: command not found`

It is `prek` here. Use `.agents/scripts/preflight.sh <files>`, or `prek run
--files <files>` inside the shell.

### `error: attribute 'foo' missing`

A host references a registry key that doesn't exist. Usually one of:

- a typo in the key string
- the file is new and **not yet `git add`ed**, so Nix cannot see it
- a path segment starts with `_`, which excludes it from discovery

```bash
grep -rn 'flake.modules.nixos.foo' modules/ hosts/ profiles/
```

### My change had no effect

Almost always an untracked file. `git status` — if your new `.nix` file is
listed as untracked, `git add` it and rebuild.

### I deployed something broken

Every deploy leaves the previous generation bootable. Roll back on the host:

```bash
sudo nixos-rebuild switch --rollback
```

or pick an older generation from the boot menu. [upgrading.md](./upgrading.md)
covers rollback in depth.

---

## Where to go next

| You want to | Read |
|---|---|
| Add a module, user, or whole host | [cookbook.md](./cookbook.md) |
| Understand why the repo is shaped this way | [architecture.md](./architecture.md) |
| Update nixpkgs or do a release upgrade | [upgrading.md](./upgrading.md) |
| Add or rotate a secret | [secrets.md](./secrets.md) |
| Set up a project-level dev environment | [devenv.md](./devenv.md) |
| Work on a non-NixOS machine | [non-nixos.md](./non-nixos.md) |
| Know the exact contract of a script | [.agents/validation.md](../.agents/validation.md) |

`AGENTS.md` at the repo root is the maintenance authority for AI agents working
on this repo. It is stricter and more detailed than this guide; where the two
disagree, `AGENTS.md` wins.
