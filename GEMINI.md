# Project Context

## Architecture Overview
This repository manages a scalable, dendritic NixOS flake configuration. The declarative architecture spans multiple hardware profiles and node types, including:  

* **Core Compute Servers:** High-resource x86_64-linux environments (e.g., dual Xeon E5-2687Wv2 profiles).
* **Edge/SBC Nodes:** aarch64-linux single-board computers (e.g., 16GB rk3588 clusters).
* **Workstations:** Mobile development machines (e.g., ThinkPad Z16 Gen 1 with AMD discrete graphics).

## AI Agent Directives: Tool Usage Strategy
You are equipped with four Model Context Protocol (MCP) servers: `context7`, `nixos-tools`, `time`, `git`, and `fetch`. Before generating or modifying any `.nix` code, strictly follow this sequence:

1. **Strategic Planning:** - Break down complex tasks (e.g., refactoring a module, resolving dependencies, hardware integration) step-by-step before writing code.
2. **Context & Repository Analysis (`git` & `fetch`):** - Use the `git` tool to review the current repository state, recent commits, or your own working tree diffs to ensure code changes align with existing patterns.  
   * Use the `fetch` tool to read the contents of any specific web URLs the user provides in their prompt.  
3. **Knowledge Retrieval (`time`, `context7` & `nixos-tools`):** - Check the `time` tool to anchor your understanding of current software releases.  
   * Use the `nix` tool with `source="wiki"` or `source="nix-dev"` to retrieve official NixOS documentation.  
   * Use `context7` to fetch the most recent community patterns for external frameworks not covered by NixOS docs.  
4. **Validation & Verification (`nixos-tools`):** - The NixOS server exposes a unified `nix` tool. You must use it to verify parameters:  
   * **Package Discovery:** Use `nix(action="search", query="<name>", source="nixos", type="packages")` to verify existence on the present NixOS channel.  
   * **Option Verification:** Use `nix(action="search", query="<key>", source="home-manager")` or `source="nixos"` to validate configuration keys and data types.  
   * **Package History:** Use the `nix_versions` tool to fetch exact commit hashes for reproducible builds if needed.  
   * **Flake Inputs:** Use `nix(action="flake-inputs", type="list")` to explore local dependencies.


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
