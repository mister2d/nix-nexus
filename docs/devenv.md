# Devenv 2.0: Next-Generation Declarative Environments

This guide details the integration and usage of **Devenv 2.0** within the `nix-nexus` framework. Devenv 2.0 represents a significant paradigm shift from imperative development setups (like global package managers or `docker-compose`) and older wrappers (like `devbox`), offering a pure, fast, and highly automated Nix-based workflow.

## 1. Why Devenv 2.0?

For engineers transitioning from traditional Linux environments or relying heavily on `docker-compose` for local development, Devenv 2.0 provides a massive upgrade in reproducibility and performance:

*   **Native Rust Process Manager:** Replaces `process-compose` with a fast, systemd-like process manager.
*   **Systemd-Style Socket Activation & Dependency Ordering:** Processes can depend on each other using readiness probes (e.g., `@ready`, `@completed`), ensuring your database is fully up before your API server starts.
*   **C FFI Evaluation Cache:** Evaluation is nearly instant thanks to a new C FFI backend and incremental caching, eliminating the sluggishness of traditional Nix CLI wrappers.
*   **Automatic Port Allocation:** Prevents port conflicts when running multiple projects simultaneously.
*   **Polyrepo Composability:** You can easily reference outputs and services from other Devenv projects using the `--from` flag, making microservices or research pipelines trivial to compose.

## 2. Integration in Nix-Nexus

Devenv 2.0 is integrated natively into our Nix Flake architecture:

1.  **Flake Input:** Devenv is pinned as a flake input (`github:cachix/devenv`) in our root `flake.nix`.
2.  **Home Manager Deployment:** The `devenv` binary is injected into the user environment via `modules/tools/dev/home.nix`, guaranteeing you are always using the locked 2.0 version.

*Note: `devbox` is temporarily retained for backwards compatibility with legacy projects, but new projects should default to Devenv.*

## 3. Daily Developer Workflow

To replace legacy `docker-compose` or `devbox` workflows, initialize a new project:

```bash
mkdir my-new-project && cd my-new-project
devenv init
```

### Example: A Modern API & Database Stack

Here is a blueprint `devenv.nix` demonstrating Devenv 2.0's powerful features. Notice how it declaratively manages dependencies without touching your root filesystem or requiring a Docker daemon:

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

Start the environment and all associated processes with:

```bash
devenv up
```

## 4. Advanced Infrastructure Patterns

### Container Exports
Devenv environments can be natively exported to OCI containers. This allows you to prototype locally in pure Nix, then instantly export the exact closure to Talos or Kubernetes (which we manage via `kubectl-rook-ceph` and `talosctl`) without ever writing a `Dockerfile`:

```bash
devenv container run shell
```

### Hardware Optimization
Our ThinkPad Z16 environments (and high-resource core servers) benefit greatly from Devenv 2.0's Rust and C implementations, especially with AVX2 instruction sets enabled, resulting in extremely fast environment evaluations and process management.

## 5. This repo's own devshell

nix-nexus's own Claude Code environment is itself devenv-managed, declared in
`modules/flake/checks.nix` via `inputs.devenv.flakeModule` and
`perSystem.devenv.shells.default` — this keeps `devShells.default` a real
flake output, so `nix develop`, `preflight.sh`, and `nix flake check` work
unchanged. `git-hooks.hooks` (nixfmt, deadnix, statix) replaces the previous
direct `pre-commit-hooks.lib.run` invocation, and `claude.code.hooks` /
`claude.code.mcpServers` generate `.claude/settings.json` and `.mcp.json` as
store-path symlinks on shell entry, replacing the hand-maintained copies.
`.envrc` activates it via `use flake --impure` — `--impure` is required
because devenv's flakeModule resolves `devenv.root` from `$PWD`
(`builtins.getEnv "PWD"`), and this repo does not declare a `devenv-root`
flake input.
