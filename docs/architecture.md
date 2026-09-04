# Architecture: The Dendritic Pattern

This document explains the structure of nix-nexus. It explains why nix-nexus
has this structure. It explains what this means when you read or edit code.

---

## The core idea in one sentence

Every `.nix` file in `modules/`, `hosts/`, and `profiles/` is a self-contained
**fragment**. Each fragment announces its own name to a shared registry. A
host builds a machine by reading names from that registry. A host never
imports a file by its path.

---

## How file discovery works

`flake.nix` uses **import-tree** to find every `.nix` file under three
subtrees:

```nix
fleet = builtins.foldl' (it: p: it.addPath p) inputs.import-tree [
  ./modules
  ./hosts
  ./profiles
];
inputs.flake-parts.lib.mkFlake { inherit inputs; } fleet.result;
```

`addPath` adds each root to the set of files to find. `fleet.result` builds a
**flake-parts** module. This module holds one `imports` list of every file
found. No file is named in `flake.nix`. You add a new `.nix` file anywhere
under these three trees. The file becomes active at the next evaluation.

> **import-tree convention**: import-tree excludes a file when a path segment
> starts with `_`. import-tree includes every other file that matches
> `*.nix`.

---

## What each file must look like

Every found file is a **flake-parts module**. The outermost shape is always
one of two forms.

```nix
# Minimal fragment — no inputs needed
_: {
  flake.modules.nixos.my-module-name = <NixOS module>;
}
```

Use this form when the fragment needs flake-level inputs:

```nix
{ inputs, config, ... }: {
  flake.nixosConfigurations.myhostname = inputs.nixpkgs.lib.nixosSystem { ... };
}
```

The underscore (`_`) or named argument set is the **flake-parts module
argument** (compare it to `{ config, pkgs, ... }` in a NixOS module). Do not
confuse it with the NixOS module argument inside the value.

---

## The two registries

`modules/flake/module-types.nix` declares two flake-level options:

```nix
flake.modules.nixos      # type: lazyAttrsOf deferredModule
flake.modules.homeManager  # type: lazyAttrsOf deferredModule
```

A fragment that sets `flake.modules.nixos.<name> = <module>` adds an entry to
the NixOS registry. A fragment that sets
`flake.modules.homeManager.<name> = <module>` adds an entry to the Home
Manager registry.

The type `lazyAttrsOf deferredModule` makes multi-file stacks possible.
Multiple fragments can register **the same name**. The module system merges
all their contributions under that one key. This is how `services-matrix`
spans nine files without an aggregator.

---

## How a host assembly works

Each host has two pieces.

### 1. The host module — `hosts/<hostname>/default.nix`

A NixOS module registered as `flake.modules.nixos.<hostname>-default`. Here
you place machine-specific configuration: `networking.hostName`, hardware
imports, kernel parameters, per-host tuning.

```nix
_: {
  flake.modules.nixos.sweet16-default =
    { nixosModules, ... }:
    {
      imports = [
        nixosModules.sweet16-hardware    # generated hardware scan
        nixosModules.hardware-z16        # ThinkPad Z16 hardware aspects
        nixosModules.workstation-default # core policies
        nixosModules.desktop-default     # desktop suite
        nixosModules.development-default # dev toolchain
        nixosModules.desktop-hyprland    # compositor
      ];
      networking.hostName = "sweet16";
      # ...machine-specific overrides...
    };
}
```

The key point: every `nixosModules.*` reference is a **name lookup** into the
registry. No path imports. The flake assembly (see next) delivers the full
registry as `nixosModules` through `specialArgs`.

### 2. The flake assembly — `modules/flake/nixos-<hostname>.nix`

A flake-parts fragment that calls `nixpkgs.lib.nixosSystem`. It binds the
registry into `specialArgs` and picks which named modules form the machine's
closure:

```nix
{ inputs, config, ... }:
let
  hm    = config.flake.modules.homeManager;
  nixos = config.flake.modules.nixos;
in
{
  flake.nixosConfigurations.sweet16 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      inherit (inputs) self;
      nixosModules      = nixos;
      homeManagerModules = hm;
    };
    modules = [
      nixos.overlays-global
      nixos.sweet16-default
      inputs.home-manager.nixosModules.home-manager
      nixos.hm-ddukes-sweet16
    ];
  };
}
```

`specialArgs` gives every NixOS module in this flake the `nixosModules` and
`homeManagerModules` function arguments. You can write
`{ nixosModules, ... }:` or `{ homeManagerModules, ... }:` in any NixOS
module and read these two names.

---

## The three tiers

```
modules/core/       Core policies — every machine via workstation-default or server-default
profiles/           Functional suites — opt-in groups of core modules
modules/            Granular aspects — hardware, services, desktop, user
```

### Core (`modules/core/`)

These modules set the base security, networking, and system hygiene posture.
No host imports them directly. Instead, `profiles/workstation` and
`profiles/server` compose them under the names `workstation-default` and
`server-default`.

| Module name | What it does |
|---|---|
| `core-boot` | LUKS initrd, kernel defaults, bootloader timeout |
| `core-networking` | NetworkManager, Tailscale, firewall, DNS |
| `core-security` | SSH, GPG, PKI certs, Polkit, PAM |
| `core-sysctl` | Kernel tuning (inotify, vm, net) |
| `core-users` | System user accounts and SSH keys |
| `core-zfs` | ZFS pool settings and ARC tuning via `nix-nexus.zfs.*` |

### Profiles (`profiles/`)

Profiles group core modules into named role bundles:

- `workstation-default` — imports core-boot + core-networking + core-security +
  core-sysctl + core-users + core-zfs
- `server-default` — imports core-security + core-sysctl + core-users
  (omits boot, ZFS, and NM — containers manage these outside NixOS)
- `desktop-default` — greetd + Wayland + fonts + theming + kernel quiet/splash
- `development-default` — common system packages, Docker, custom scripts

### Modules (`modules/`)

Everything else lives here: hardware aspects, compositor configs, service
stacks, user HM profiles. Each file is a focused, opt-in capability fragment.

---

## Home Manager wiring

Home Manager integration for a NixOS host uses two more fragments.

**`hosts/<hostname>/<user>-hm.nix`** — NixOS-side wiring. Registered as a
`flake.modules.nixos` entry. This fragment configures the `home-manager`
NixOS module and maps a HM profile to a system user:

```nix
_: {
  flake.modules.nixos.hm-ddukes-sweet16 =
    { inputs, homeManagerModules, ... }:
    {
      home-manager = {
        useGlobalPkgs    = true;
        useUserPackages  = true;
        backupFileExtension = "bak";
        extraSpecialArgs = {
          inherit (inputs) self;
          inherit inputs homeManagerModules;
        };
        users.ddukes.imports = [
          inputs.nixvim.homeModules.nixvim
          homeManagerModules.sweet16-home
        ];
      };
    };
}
```

**`hosts/<hostname>/home.nix`** — The HM profile itself. Registered under
`flake.modules.homeManager.<hostname>-home`. This fragment imports named HM
modules and adds host-specific overrides:

```nix
_: {
  flake.modules.homeManager.sweet16-home =
    { pkgs, homeManagerModules, ... }:
    {
      imports = [
        homeManagerModules.user-home
        homeManagerModules.hardware-z16-hypr-home
        homeManagerModules.desktop-hyprland-home
        homeManagerModules.desktop-noctalia-home
        homeManagerModules.desktop-theme-home
      ];
      programs.btop.package = pkgs.btop.override { rocmSupport = true; };
    };
}
```

---

## Standalone Home Manager (non-NixOS hosts)

For a machine that runs a foreign Linux (Debian, Armbian, and so on), one
flake-parts fragment maps every host for one user. `modules/flake/hm-groot.nix`
builds `groot@dualie`, `groot@forge`, and `groot@rk3588` from one
host-to-system table:

```nix
{ inputs, config, lib, ... }:
let
  hm = config.flake.modules.homeManager;
  hosts = {
    dualie = "x86_64-linux";
    forge = "x86_64-linux";
    rk3588 = "aarch64-linux";
  };
in
{
  flake.homeConfigurations = lib.mapAttrs' (
    host: system:
    lib.nameValuePair "groot@${host}" (
      inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        modules = [ inputs.nixvim.homeModules.nixvim hm."${host}-home" ];
        extraSpecialArgs = {
          inherit (inputs) self;
          inherit inputs;
          homeManagerModules = hm;
        };
      }
    )
  ) hosts;
}
```

Activate it with:
```bash
nix run home-manager/release-26.05 -- switch --flake .#groot@dualie -b bak
```

---

## Naming conventions

| Scope | Convention | Examples |
|---|---|---|
| Core NixOS | `core-<subsystem>` | `core-networking`, `core-zfs` |
| Profiles | `<role>-default` | `workstation-default`, `server-default`, `desktop-default` |
| Hardware NixOS | `hardware-<platform>` | `hardware-z16`, `hardware-petunia` |
| Hardware HM | `hardware-<platform>-<compositor>-home` | `hardware-z16-hypr-home`, `hardware-petunia-hypr-home` |
| Services | `services-<stack>` | `services-matrix` |
| Desktop NixOS | `desktop-<compositor>` | `desktop-hyprland` |
| Desktop HM | `desktop-<compositor>-home` | `desktop-hyprland-home`, `desktop-noctalia-home` |
| User HM | `user-<aspect>` | `user-home`, `user-bash`, `user-neovim-home` |
| Host NixOS | `<hostname>-default` | `sweet16-default`, `hermes-default` |
| Host HM | `<hostname>-home` | `sweet16-home`, `dualie-home` |
| HM wiring (NixOS) | `hm-<user>-<hostname>` | `hm-ddukes-sweet16`, `hm-groot-hermes` |

---

## Custom options (`nix-nexus.*`)

A module can declare custom options in the `nix-nexus` namespace. The
convention is `nix-nexus.<subsystem>.<option>`:

```nix
# Declaration (modules/core/zfs.nix)
options.nix-nexus.zfs.arcMax = lib.mkOption { type = lib.types.int; ... };

# Usage (hosts/sweet16/default.nix)
nix-nexus.zfs.arcMax = 8589934592;
```

Currently declared options:
- `nix-nexus.zfs.*` — ZFS ARC limits and dataset tuning
- `nix-nexus.networking.tailscale.homeSSIDs` — SSIDs that suppress Tailscale routes

---

## `lib/` — helpers that are not modules

Files under `lib/` are plain Nix expressions, not flake-parts fragments. You
import each one by a relative path where you need it. import-tree does not
find these files.

- `lib/custom-scripts.nix` — returns `{ pkgs }: { battery-alert = ...; system-stats = ...; }` 
- `lib/keymap.nix` — the canonical multiplexer keymap plus `renderTmux` and
  `renderHerdr`. Both `programs.tmux` and herdr read their bindings from this
  one source
- `lib/openclaude.nix` — npm package derivation
- `lib/avina/site-config.nix` — pure data attrset for avina domain constants

Do not place module logic in `lib/`. Do not place pure helper logic in
`modules/`.
