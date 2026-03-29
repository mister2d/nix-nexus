# Dendritic Architecture: The Den Model

This guide provides a deep-dive into the technical philosophy and structural patterns used in `nix-nexus` via the **Den framework**.

## 1. The Core Philosophy: Aspect-Orientation
Traditional NixOS configurations separate "System" (NixOS modules) from "User" (Home Manager modules). This leads to fragmentation: to add a feature like **Sway**, you must touch multiple files across different directories.

**Den** eliminates this split. Instead, we use **Aspects**.

An Aspect is a functional unit that owns its configuration across all domains. For example, `modules/sway.nix` contains:
- The `programs.sway.enable` NixOS option.
- The `wayland.windowManager.sway.config` Home Manager settings.
- Any hardware-specific quirks (via `provides`).

## 2. Automated Discovery (`import-tree`)
Nix-Nexus uses the **`import-tree`** pattern. The `flake.nix` entry point does not explicitly import every file. Instead, it passes the `modules/` directory to the Den pipeline.

- **Dendritic Scanning**: Every `.nix` file in `modules/` is automatically registered.
- **Quarantining**: Files or directories prefixed with an underscore (e.g., `modules/_hw/`) are **ignored** by the scanner. This is useful for machine-specific configs that shouldn't be global aspects.

## 3. The Fleet Control Plane (`modules/hosts.nix`)
While aspects define *how* features work, the **Fleet Registry** defines *where* they go.

`modules/hosts.nix` is the single source of truth for the entire fleet. It uses the `den.hosts` (NixOS) and `den.homes` (Standalone Home Manager) attributes to map hosts to aspects.

```nix
den.hosts.x86_64-linux.sweet16 = {
  includes = [
    den.aspects.base-aspect
    den.aspects.sway-aspect
    den.aspects.hw-z16-aspect
  ];
};
```

## 4. Domain Unification Patterns

### Guarded Forwarding
Den allows for advanced routing between system and user domains. This is particularly useful for:
- **Impermanence**: Forwarding system-level persistence paths to user-level home directories.
- **Secrets**: Passing runtime secret paths from the system to user applications.

### Mutual Providers
When a host and a user need to negotiate configuration (e.g., a host providing a specific GPU driver that a user's terminal needs to bridge), we use the **`mutual-provider`** pattern. This ensures that the user's environment is always aware of the host it's running on.

## 5. Migration and Evolution
The Den model is designed for evolution. Because aspects are independent nodes in a directed acyclic graph (DAG), you can safely add, remove, or refactor features without breaking unrelated hosts.

For more information on the Den framework, visit the [official repository](https://github.com/vic/den).
