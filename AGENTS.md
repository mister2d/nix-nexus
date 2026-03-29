# AGENTS.md — nix-nexus (Dendritic Edition)

> **README for AI Coding Agents.** Read completely before acting. Compatible with Claude Code
> (`CLAUDE.md`), OpenAI Codex, Gemini CLI, Cursor, Aider, opencode, and all agents that
> honour the AGENTS.md standard.

---

## Project Overview

**nix-nexus** is a modular, aspect-oriented NixOS configuration framework powered by the
**Den framework (v0.13.0)**. It follows a **Dendritic** architecture where system and
user configuration are unified into **Aspects**.

Primary language: **Nix**. Supporting: **Bash**, **Python**.
HashiCorp toolchain: Vault 1.21.1, Consul 1.22.1, Terraform 1.14.5, Nomad 1.10.5.

---

## Dendritic Repository Structure

The framework uses **`import-tree`** for automatic discovery. Any file in `modules/` 
not starting with `_` is automatically evaluated as an Aspect.

```text
flake.nix                   # Minimal orchestrator (flake-parts + Den pipeline)
certs/                      # Internal CA cert chain
modules/
  hosts.nix                 # Fleet Control Plane: Host and Home registry
  base.nix                  # Foundational core (StateVersion, Timezone, ZFS)
  boot.nix                  # Unified Boot & LUKS aspect
  networking.nix            # Unified Networking & Firewall aspect
  matrix.nix                # Matrix 2.0 stack aspect (gateway to _matrix/)
  sway.nix                  # Desktop aspect (NixOS + Home Manager)
  user-ddukes.nix           # Personal user aspect
  _hw/                      # Machine-specific non-portable configs (scanned, ignored)
  _matrix/                  # Matrix internal service modules (quarantined)
docs/
  den-architecture.md       # Technical guide to the Dendritic model
```

---

## The Den Aspect Model

### Unified Domains
Unlike traditional NixOS, an aspect (e.g., `sway.nix`) handles both the system and the user:
```nix
{ den, ... }: {
  den.aspects.sway-aspect = {
    nixos = { pkgs, ... }: { ... };       # System domain
    homeManager = { pkgs, ... }: { ... }; # User domain
  };
}
```

### Automatic Discovery
Do **NOT** manualy add imports to `flake.nix`. Simply create a new file in `modules/`
and it will enter the `den.aspects` or `den.provides` namespace automatically.

---

## Host Reference (Control Plane)

All hosts are defined in **`modules/hosts.nix`** using the `den.hosts` and `den.homes`
registry.

| Host | Type | OS | Arch |
|---|---|---|---|
| `sweet16` | Workstation | NixOS | x86_64-linux |
| `petunia` | Desktop | NixOS | x86_64-linux |
| `avina` | Server | NixOS | x86_64-linux |
| `dualie` | Standalone | Debian | x86_64-linux |
| `forge` | Standalone | Debian | x86_64-linux |
| `rk3588` | Standalone | Debian | aarch64-linux |

---

## Coding Standards (mcp-nixos Mandatory)

Query `mcp-nixos` before emitting any option path, package name, or module attribute.

- **`networking.hostId`**: unique 8-char hex; `head -c4 /dev/urandom | xxd -p`
- **`home.stateVersion`**: always `"25.11"` to match codebase
- **Secrets**: Reference only runtime paths: `/run/secrets/foo`, `/run/certs/foo.pem`
- **Linter**: `nix develop --command pre-commit run --files <modified>`

---

## Common Patterns

### Creating a New Aspect
Use the following skeleton for a new feature aspect:
```nix
{ den, lib, pkgs, inputs, ... }: {
  den.aspects.<feature>-aspect = {
    nixos = { ... }: { ... };
    homeManager = { ... }: { ... };
  };
}
```

### Quarantining Non-Portable Modules
If a module is specific to a single host (e.g., `_hw/petunia/disko.nix`), prefix its
parent directory with `_` to hide it from Den's automatic aspect scanner. Import it
manually inside the host's `nixos` block in `modules/hosts.nix`.

---

## Testing

### Before Every Commit
```bash
nixfmt <modified>.nix
statix check .
deadnix .
nix flake check
nix eval .#nixosConfigurations.<hostname>.config.system.build.toplevel
```

---

*Built for Gemini CLI, Claude Code, and Opencode agents.*
