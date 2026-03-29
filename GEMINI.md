# Project Context

## Architecture Overview
This repository manages a scalable, **dendritic NixOS configuration framework** powered
by the **Den framework (v0.13.0)**. The aspect-oriented architecture spans multiple 
hardware profiles and node types, including:  

* **Core Compute Servers:** High-resource x86_64-linux environments (e.g., Dual Xeon).
* **Edge/SBC Nodes:** aarch64-linux single-board computers (e.g., 16GB rk3588 clusters).
* **Workstations:** Mobile development machines (e.g., ThinkPad Z16 Gen 1 with AMD discrete graphics).

The system uses a **Unified Aspect model** where each feature (Desktop, Matrix, Networking) 
is defined in a single file across both system (NixOS) and user (Home Manager) domains.

## AI Agent Directives: Tool Usage Strategy
You are equipped with MCP servers: `nixos-tools`, `time`, `git`, and `fetch`. Before 
generating or modifying any `.nix` code, strictly follow this sequence:

1. **Strategic Planning:** Break down complex tasks step-by-step.
2. **Context Analysis:** Use `git` to review the repository state.  
3. **Knowledge Retrieval:**  
   * Use `time` to anchor understanding of software releases.  
   * Use `nixos-tools` to search packages and validate options across NixOS and Home Manager.
4. **Validation:** Use `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel` 
   or `nix flake check` to verify changes.

## Execution Workflow (The Den Cycle)
When tasked with creating or modifying configurations, follow this dendritic loop:

1. **Generate Code (Aspect-First):**
   - Create or modify a single Aspect file in `modules/`. 
   - Ensure the aspect adheres to the unified domain pattern (`nixos` and `homeManager` keys).
   - Den will automatically discover and wire the new aspect.

2. **Pre-Commit Enforcement (Lint & Format):**
   - The repository uses `nixfmt-rfc-style`, `deadnix`, and `statix`.
   - Run: `!nix develop --command pre-commit run --files <modified_file.nix>`

3. **Fleet-Wide Validation:**
   - Validate the host registry in `modules/hosts.nix`.
   - Run: `!nix flake check` or `!nix flake show`.

4. **Documentation and comments:** Ensure generated code reflects the cohesive story
   of the dendritic architecture.

---
*For technical deep-dives into the framework, see `docs/den-architecture.md`.*
