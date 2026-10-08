# Developer Tooling: nix-devshell

nix-nexus does not install developer tooling. AI coding agents, HashiCorp
and Kubernetes CLIs, openclaude, `llm-init`, and the general development
toolchain live in the separate `nix-devshell` flake:

- Remote: `git+ssh://gitea@code-ssh.novuscotia.com/novuscotia-ops/nix-devshell`
- Local copy: `~/workspace/nix-devshell`

Single-home rule: nothing in that set is defined in both repositories.

## Call a shell

```bash
FLAKE=git+ssh://gitea@code-ssh.novuscotia.com/novuscotia-ops/nix-devshell

nix develop $FLAKE#hashicorp     # nomad, vault, consul, terraform, tflint, envsubst
nix develop $FLAKE#talos         # talosctl, omnictl, helm, kubelogin-oidc, kubectl-rook-ceph
nix develop $FLAKE#llm-agents    # claude, opencode, openclaude, llm-init, rocm-init
nix develop $FLAKE#full          # everything above plus devenv, devbox, uv, nodejs, meld, butane
```

Run one command and leave:

```bash
nix develop $FLAKE#hashicorp --command terraform version
```

Add `--refresh` to read the current tip instead of the cached copy. The
consumer shells need no `--impure`. Do not call `#default` remotely. It is the
contributor shell for the nix-devshell repository.

## Use it from direnv

In a project directory:

```bash
echo 'use flake git+ssh://gitea@code-ssh.novuscotia.com/novuscotia-ops/nix-devshell#hashicorp' > .envrc
direnv allow
```

## Project bootstrap scripts

```bash
nix develop $FLAKE#llm-agents --command llm-init    # CUDA project flake plus .envrc
nix develop $FLAKE#llm-agents --command rocm-init   # ROCm project flake plus .envrc
```

## Where nix-nexus consumes it

Only the `hermes` host takes nix-devshell as a flake input. The input follows
nix-nexus's `nixpkgs-unstable`, `flake-parts`, and `import-tree`.

| File | Use |
|---|---|
| `hosts/hermes/mcp-overlay.nix` | applies `overlays.default` (context-mode) |
| `hosts/hermes/llm-agents-overlay.nix` | imports `nixosModules.dev-hermes-agent` (vendored hermes-agent plus the context-mode-hermes plugin) |
| `hosts/hermes/groot-hm.nix` | uses `overlays.buildFixes` for the unstable package set |

Bump it with `nix flake update nix-devshell`, then verify hermes drift with
`.agents/scripts/verify-drift.sh`. Always build the `hermes` configuration
before signing off a bump.

Every other host (sweet16, petunia, avina, dualie, forge, rk3588) calls the
shells on demand and installs nothing from nix-devshell.

The `devenv` CLI and direnv (with nix-direnv) stay installed on sweet16,
petunia, dualie, forge, and rk3588. `modules/user/devenv-home.nix`
(`user-devenv-home`) provides them, so `devenv shell`, `nix develop`, and
`use flake` in an `.envrc` can call nix-devshell from the CLI. The `devenv`
binary comes from nix-nexus's `devenv` flake input.

## Maintaining the tooling

Changes to the tool set, pins, and overlays belong in the nix-devshell
repository. Do not add them here. See that repository's `README.md` and
`AGENTS.md`.
