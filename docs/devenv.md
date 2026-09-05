# Devenv 2.0: Declarative Development Environments

This guide covers **Devenv 2.0** inside the `nix-nexus` framework. Devenv
2.0 replaces imperative development setups (global package managers or
`docker-compose`) and older wrappers (like `devbox`) with a pure, fast,
Nix-based workflow.

## 1. Why Devenv 2.0?

Devenv 2.0 gives a large gain in reproducibility and speed. This applies
to engineers from traditional Linux environments, and to engineers who
rely on `docker-compose` for local development:

*   **Native Rust Process Manager:** Replaces `process-compose` with a fast, systemd-like process manager.
*   **Systemd-Style Socket Activation & Dependency Ordering:** Processes can depend on each other through readiness probes (for example `@ready`, `@completed`). Your database starts fully before your API server starts.
*   **C FFI Evaluation Cache:** Evaluation runs almost instantly through a new C FFI backend and incremental caching. This removes the slowness of older Nix CLI wrappers.
*   **Automatic Port Allocation:** Prevents port conflicts when you run multiple projects at the same time.
*   **Polyrepo Composability:** Reference outputs and services from other Devenv projects with the `--from` flag. This makes microservices or research pipelines easy to compose.

## 2. Integration in Nix-Nexus

Devenv 2.0 is part of our Nix Flake architecture:

1.  **Flake Input:** Devenv is pinned as a flake input (`github:cachix/devenv`) in our root `flake.nix`.
2.  **Home Manager Deployment:** The `devenv` binary reaches the user environment through `modules/user/dev-home.nix`. This guarantees you always run the locked 2.0 version.

*Note: `devbox` stays available for older projects. New projects should default to Devenv.*

## 3. Daily Developer Workflow

To replace older `docker-compose` or `devbox` workflows, start a new project:

```bash
mkdir my-new-project && cd my-new-project
devenv init
```

### Example: An API & Database Stack

Here is an example `devenv.nix` that shows Devenv 2.0 features. It manages
dependencies declaratively, without touching your root filesystem or a
Docker daemon:

```nix
{ pkgs, config, ... }: {
  # 1. Define your toolchain
  packages = [ pkgs.python3 pkgs.uv ];

  processes = {
    # 2. Database Service
    database = {
      exec = "postgres -D .local/pgdata";
      # 2.0 Feature: Automatic port allocation prevents conflicts
      ports.tcp.allocate = 5432;
    };
    
    # 3. API Service
    api = {
      exec = "uv run fastapi dev main.py";
      # 2.0 Feature: Systemd-style dependency ordering with readiness probes
      after = [ "devenv:processes:database@ready" ];
      # 2.0 Feature: File watching for live restarts
      watch.paths = [ ./src ];
    };
  };
}
```

Start the environment and all its processes with:

```bash
devenv up
```

## 4. Advanced Infrastructure Patterns

### Container Exports
Devenv environments export natively to OCI containers. You can prototype
locally in pure Nix, then export the same closure to Talos or Kubernetes
(managed here through `kubectl-rook-ceph` and `talosctl`) without writing a
`Dockerfile`:

```bash
devenv container run shell
```

### Hardware Optimization
Our ThinkPad Z16 environments, and high-resource core servers, gain from
Devenv 2.0's Rust and C implementations. With AVX2 instruction sets
enabled, environment evaluation and process management run fast.

## 5. This repo's own devshell

nix-nexus manages its own Claude Code environment through devenv. The
declaration lives in `modules/flake/checks.nix`, through
`inputs.devenv.flakeModule` and `perSystem.devenv.shells.default`. This
keeps `devShells.default` a real flake output. `nix develop`,
`preflight.sh`, and `nix flake check` all work.

`git-hooks.hooks` (nixfmt, deadnix, statix) sets up the pre-commit checks.
`claude.code.hooks` and `claude.code.mcpServers` generate
`.claude/settings.json` and `.mcp.json` as store-path symlinks on shell
entry. `.envrc` activates the shell through `use flake --impure`. The
`--impure` flag is required. devenv's flakeModule reads `devenv.root` from
`$PWD` through `builtins.getEnv "PWD"`, and this repo does not declare a
`devenv-root` flake input.
