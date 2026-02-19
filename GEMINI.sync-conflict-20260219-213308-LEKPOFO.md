# Nix-Nexus Project Context

## Architecture Overview
This repository manages a scalable, dendritic NixOS flake configuration. The declarative architecture spans multiple hardware profiles and node types, including:
* **Core Compute Servers:** High-resource x86_64-linux environments (e.g., dual Xeon E5-2687Wv2 profiles).
* **Edge/SBC Nodes:** aarch64-linux single-board computers (e.g., 16GB rk3588 clusters).
* **Workstations:** Mobile development machines (e.g., ThinkPad Z16 Gen 1 with AMD discrete graphics).

## AI Agent Directives: MCP Tool Usage
You are connected to NixOS-specific tools via the `mcp-servers-nix` integration. Before generating or modifying any `.nix` code, leverage these tools to guarantee accuracy:
1. **Package Discovery:** Use `nixos_search` and `nixos_info` to verify package names and availability on the 25.11 channel.
2. **Option Verification:** Use `hm_search` (Home Manager) or NixOS options tools to validate configuration keys and data types.
3. **Flake Inputs:** Verify upstream schemas using the provided Nix tooling before modifying inputs.

## Execution Workflow
When tasked with creating or modifying configurations, you must follow this strict execution loop to satisfy the repository's CI/CD requirements:

1. **Generate Code:**
   - Draft the `.nix` configuration using standard Nix styling and modular organization.
   - Anticipate the repository's strict linting: Code must comply with RFC 166 formatting, contain zero unused variables, and avoid Nix anti-patterns.
   - Use the `@` command to read existing local flake structures for surrounding context.

2. **Pre-Commit Enforcement (Lint & Format):**
   - The repository uses `cachix/pre-commit-hooks.nix` with `nixfmt-rfc-style`, `deadnix`, and `statix` enabled.
   - Execute the local git pre-commit hooks using the CLI's `!` shell passthrough to format and lint your changes.
   - Run: `!nix develop --command pre-commit run --files <modified_file.nix>`
   - If the hook fails or modifies the file, review the terminal output, apply corrections, and re-run.

3. **Tree-Wide Validation:**
   - Perform a dry-run evaluation to validate the entire flake tree structure and ensure all derivation checks pass.
   - Run: `!nix flake check`
   - You may only consider the code generation complete when `nix flake check` exits successfully without evaluation errors.
