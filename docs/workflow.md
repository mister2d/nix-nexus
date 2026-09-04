# Development workflow

This guide is for day one. It shows you how to change something in
nix-nexus and deploy it to a machine. It assumes you know git and a
terminal. It assumes you know little or no Nix. You do not need to
understand the dendritic pattern to follow this guide. Read
[architecture.md](./architecture.md) to learn why the repo has this shape.

If you read nothing else, read [the loop at a glance](#the-loop-at-a-glance)
and [when something goes wrong](#when-something-goes-wrong).

---

## The mental model

This repo has three different things. All three are called "Nix". People
often confuse these three things at first. Treat them as separate layers:

| Layer | What it configures | Where it lives | Applied by |
|---|---|---|---|
| **Dev shell** | *Your tools while working on this repo* — formatters, linters, `sops`, `age` | `modules/flake/checks.nix` | entering the directory (direnv) or `nix develop --impure` |
| **NixOS system** | A whole machine — kernel, services, users, packages | `modules/`, `hosts/`, `profiles/` | `deploy-host.sh <host>` |
| **Home Manager** | One user's environment — shell config, aliases, dotfiles | same tree, `homeManager` modules | same deploy, or `home-manager switch` on standalone hosts |

The dev shell does not affect the machines you deploy. A linter change in
`checks.nix` does not change any host.

### The fleet

The fleet has seven configurations. Four are full NixOS machines. You
deploy to these four machines. Three are only a user environment. Someone
else manages the machine for each of these three.

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

With direnv, you enter the dev shell automatically when you `cd` in.
Without direnv, run this command every time:

```bash
nix develop --impure
```

**`--impure` is mandatory. It is not cosmetic.** The dev shell needs to
know its own directory. It finds the directory by reading `$PWD`. Nix
refuses to read `$PWD` in pure mode. Every `nix develop` and
`nix flake check` command against this repo needs `--impure`. Plain
`nix develop` fails. It shows a confusing assertion. The assertion says Nix
cannot determine the current directory.

The first entry builds the whole dev shell. This can take a few minutes.
Later entries use the cache and start instantly.

### Things you must not hand-edit

Entering the shell generates several files. These files are symlinks into
the read-only Nix store. If you edit one of these files, the edit fails.
Or the next shell entry silently discards your edit:

| File | Generated from |
|---|---|
| `.pre-commit-config.yaml` | `modules/flake/checks.nix` (`git-hooks.hooks`) |
| `.claude/settings.json` | `modules/flake/checks.nix` (`claude.code`) |
| `.mcp.json` | same |

To change linting or hooks, edit `modules/flake/checks.nix` and re-enter
the shell.

Entering the shell also installs the git pre-commit hook. You do not need
to run an install command.

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

Small doc-only edits skip every step from *check* onward. The full loop
applies to changes under `modules/`, `hosts/`, `profiles/`, `flake.nix`, or
`flake.lock`. These paths affect a machine. This guide calls these paths
**evaluated config**.

---

## Step 1 — Find what to change

Nix-nexus has no central list of modules. Nix-nexus discovers every `.nix`
file under `modules/`, `hosts/`, or `profiles/` automatically. Each file
registers itself under a name. So the usual question is: which file owns
this setting?

```bash
# Search the tree
grep -rn 'tailscale' modules/ hosts/ profiles/

# List every registry name that exists (39 of them at time of writing)
nix eval --json .#modules.nixos --apply builtins.attrNames | jq
nix eval --json .#modules.homeManager --apply builtins.attrNames | jq

# Which hosts actually use a given module or flake input?
.agents/scripts/consumers.sh core-tpm2
```

`consumers.sh` is the important script here. It follows module-to-module
references. It tells you which *hosts* include a key:

```
sweet16: via hosts/sweet16/default.nix
petunia: via hosts/petunia/default.nix
```

That list is your **expected blast radius**. Write down this list. In step
4, you compare it against what actually changed.

If you want to add something new, instead of editing something that
exists, use the [cookbook](./cookbook.md). It has seven step-by-step
recipes: new module, new user, new host, and more. Start there.

---

## Step 2 — Make the change

Edit the file. Two rules matter more than the rest:

**Make one logical change per commit.** Linting and drift checks run per
commit. A commit with two unrelated changes is hard to validate. It is
also hard to revert cleanly.

**Never import another module by file path.** Modules reference each
other by registry name. They use a `nixosModules` or `homeManagerModules`
argument:

```nix
# correct
imports = [ nixosModules.core-tpm2 ];

# wrong — breaks the pattern
imports = [ ../../modules/core/tpm2.nix ];
```

If you add a brand-new file, **run `git add` on it before you build.** Nix
evaluates only the *git-tracked* tree. Nix ignores an untracked new `.nix`
file silently. Your build succeeds. But nothing changes, and you do not
know why.

### Don't guess package or option names

Package attributes and option paths change between nixpkgs releases. A
name you remember may not exist any more, or nixpkgs may have renamed it.
Look up the name. Do not guess it:

```bash
nix eval --raw nixpkgs#ripgrep.name        # does this attribute exist?
```

Inside an AI session, the `nixos-tools` MCP server does this directly for
you. Either way, verify the name before you write it.

---

## Step 3 — Lint

```bash
.agents/scripts/preflight.sh modules/user/bash.nix hosts/sweet16/default.nix
```

This runs two gates and stops at the first failure:

1. the formatting/lint hooks on the files you name
2. `nix flake check --impure`, which evaluates all seven configurations

Three linters run:

| Linter | Catches |
|---|---|
| `nixfmt` | Formatting. **Rewrites your file in place** |
| `deadnix` | Unused bindings and unused function arguments |
| `statix` | Nix anti-patterns — `{ ... }:` that should be `_:`, `with pkgs;`, and similar |

**When `nixfmt` reformats a file, re-stage it and run again.** That is
normal, not an error. Do not fight the formatter.

> The command here is `prek`, not `pre-commit`. `prek` is a faster
> drop-in replacement for `pre-commit`. This repo does not install
> `pre-commit`. Inside an already-entered shell, you can run
> `prek run --files <files>` directly. Prefer `preflight.sh`. It also runs
> the flake check, and it sets `--impure` correctly.

Then commit normally. The git hook re-runs the linters on staged files.

---

## Step 4 — Check the blast radius

This step shows the difference between "it evaluates" and "it does what I
meant". Skip this step only for doc-only changes.

```bash
# what flake inputs moved, if any?
.agents/scripts/lock-diff.sh <base-commit> HEAD

# which configs actually changed?
.agents/scripts/verify-drift.sh <base-commit> HEAD
```

`verify-drift.sh` prints a table of all seven configs. Each config shows
`none`, `DRIFT`, or `N/A`. The script exits with code `10` if anything
drifted. Use the last signed-off commit as your base:

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

Every change to evaluated config needs a recorded judgment. You must
record this judgment before you push the change. The push guard enforces
this rule. See [when something goes wrong](#the-push-guard-blocked-my-push).

```bash
.agents/scripts/signoff.sh --slug tailscale-exit-node <<'EOF'
### Expected-drift set

sweet16 and petunia — the only consumers of `core-tailscale`
(from `consumers.sh`).

### Actual vs expected

Equal. verify-drift reports DRIFT on exactly those two, `none` elsewhere.
EOF
```

You supply **only the prose**. The script generates the filename, the
timestamp, the commit list, the drift table, every store hash, and the
verdict header. Then it writes:

- `.agents/signoff/<date>-<slug>.md`: one immutable entry for each
  sign-off
- `.agents/baseline.json`: the current state. The script replaces this
  file each time.

Never type a store hash into a sign-off by hand. If you need a store
hash, let the script generate it instead.

Always use these headings: `### Expected-drift set` and
`### Actual vs expected`. Add `### Root cause` when the actual and
expected drift differ. Add `### Deploy note` when you deployed something.

If the drift does **not** match what you expect, do not sign off. Record
your investigation, but do not advance the baseline:

```bash
.agents/scripts/signoff.sh --slug weird-drift --verdict blocked <<'EOF'
...
EOF
```

Then commit the sign-off. It is a normal commit. By convention, it is its
own separate commit:

```bash
git add .agents && git commit -m "docs(signoff): record tailscale exit node drift"
```

---

## Step 6 — Deploy

> **`sweet16` is very likely the machine you are sitting at.** A `switch`
> restarts user services. It can disturb a running desktop session. For
> compositor, shell, or theming changes, use `--boot`. This applies the
> change at the next boot. Let the user reboot on their own schedule.

Deploys are always remote, even to the local machine. Deploys always
authenticate with a short-lived Vault-issued SSH certificate. There is no
local-sudo path.

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

The script runs four stages. It stops at the first failure. The stages
are: certificate check, SSH reachability check, `nixos-rebuild`, and a
generation check. The generation check confirms the machine runs what you
built.

To time a build without deploying:

```bash
.agents/scripts/build-host.sh sweet16
```

### Before your first deploy

You need an SSH certificate at `~/.ssh/id_ed25519-cert.pub`. The CA in
`certs/trusted_ssh_ca.pub` must sign this certificate. The certificate
must have the principal `root`. The certificate must have more than 30
minutes of validity left. Check the certificate:

```bash
.agents/scripts/cert-check.sh
```

**Getting and refreshing this certificate is a manual step. This repo
does not store the command. Ask the maintainer.** This repo does not
automate certificate renewal. This is deliberate. `cert-check.sh` tells
you when the certificate is expiring. `cert-check.sh` does not fix the
certificate. The deploy script does not fix it either.

### Standalone Home Manager hosts

These scripts do not deploy `dualie`, `forge`, or `rk3588`. Each of these
hosts manages itself. Run this command on the host itself:

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

You changed evaluated config. You have not signed off on this change.
This is working as intended. Complete
[step 5](#step-5--sign-off). Commit the sign-off. Push again.

The guard checks every outgoing commit that touches `modules/`, `hosts/`,
`profiles/`, or `flake.*`. Each of these commits must be an ancestor of
`signed_off_through` in `.agents/baseline.json`. Having *a* sign-off in
the range is not enough. The sign-off must cover your commits. A sign-off
written for an earlier commit does not cover your commits.

This hook runs only inside an AI coding session. It is a safety net for
automation. It does not lock you out.

### `nix develop` fails with an assertion about the current directory

You forgot `--impure`. See [one-time setup](#one-time-setup).

### `pre-commit: command not found`

It is `prek` here. Use `.agents/scripts/preflight.sh <files>`. Or use
`prek run --files <files>` inside the shell.

### `error: attribute 'foo' missing`

A host references a registry key that does not exist. This usually has
one of these causes:

- a typo in the key string
- the file is new. You have **not yet run `git add` on it**. Nix cannot
  see the file
- a path segment starts with `_`. This excludes the file from discovery

```bash
grep -rn 'flake.modules.nixos.foo' modules/ hosts/ profiles/
```

### My change had no effect

Almost always, the cause is an untracked file. Run `git status`. If your
new `.nix` file appears as untracked, run `git add` on it and rebuild.

### I deployed something broken

Every deploy leaves the previous generation bootable. Roll back on the
host:

```bash
sudo nixos-rebuild switch --rollback
```

Or pick an older generation from the boot menu.
[upgrading.md](./upgrading.md) covers rollback in depth.

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

`AGENTS.md` at the repo root is the maintenance authority for AI agents
working on this repo. It is stricter and more detailed than this guide.
Where the two disagree, `AGENTS.md` wins.
