# Architecture: The Dendritic Pattern

This document explains how nix-nexus is structured, why it is structured that way,
and what that means in practice when you are reading or editing code.

---

## The core idea in one sentence

Every `.nix` file in `modules/`, `hosts/`, and `profiles/` is a self-contained
**fragment** that announces its own name to a shared registry. Hosts compose
machines by reading names from that registry — never by importing files by path.

---

## How file discovery works

`flake.nix` uses **import-tree** to discover all `.nix` files under three subtrees:

```nix
fleet = builtins.foldl' (it: p: it.addPath p) inputs.import-tree [
  ./modules
  ./hosts
  ./profiles
];
inputs.flake-parts.lib.mkFlake { inherit inputs; } fleet.result;
```

`addPath` appends each root to the discovery set. `fleet.result` produces a
**flake-parts** module containing one big `imports` list of every discovered file.
No file is explicitly named in `flake.nix`; adding a new `.nix` file anywhere
under those three trees makes it live automatically on the next evaluation.

> **import-tree convention**: files with a path segment starting with `_` are
> excluded. Everything else matching `*.nix` is included.

---

## What each file must look like

Every discovered file is evaluated as a **flake-parts module**. The outermost
shape is always:

```nix
# Minimal fragment — no inputs needed
_: {
  flake.modules.nixos.my-module-name = <NixOS module>;
}
```

or, when the fragment needs flake-level inputs:

```nix
{ inputs, config, ... }: {
  flake.nixosConfigurations.myhostname = inputs.nixpkgs.lib.nixosSystem { ... };
}
```

The underscore (`_`) or named argument set is the **flake-parts module argument**
(analogous to `{ config, pkgs, ... }` in a NixOS module). Do not confuse it with
the NixOS module argument that appears inside the value.

---

## The two registries

`modules/flake/module-types.nix` declares two flake-level options:

```nix
flake.modules.nixos      # type: lazyAttrsOf deferredModule
flake.modules.homeManager  # type: lazyAttrsOf deferredModule
```

Every fragment that sets `flake.modules.nixos.<name> = <module>` adds an entry to
the NixOS registry. Every fragment that sets `flake.modules.homeManager.<name> = <module>`
adds to the Home Manager registry.

The type `lazyAttrsOf deferredModule` is what makes multi-file stacks possible:
multiple fragments can register **the same name** and the module system merges all
their contributions under that single key. This is how `services-matrix` spans nine
files without an aggregator.

---

## How a host assembly works

Each host has two pieces:

### 1. The host module — `hosts/<hostname>/default.nix`

A NixOS module registered as `flake.modules.nixos.<hostname>-default`. This is
where machine-specific configuration lives: `networking.hostName`, hardware
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
registry. No path imports. The full registry is delivered as `nixosModules` via
`specialArgs` in the flake assembly (see next).

### 2. The flake assembly — `modules/flake/nixos-<hostname>.nix`

A flake-parts fragment that calls `nixpkgs.lib.nixosSystem`, binding the registry
into `specialArgs` and selecting which named modules form the machine's closure:

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

`specialArgs` is how every NixOS module in this flake receives `nixosModules` and
`homeManagerModules` as function arguments — those two names are available anywhere
you write `{ nixosModules, ... }:` or `{ homeManagerModules, ... }:`.

---

## The three tiers

```
modules/core/       Core policies — every machine via workstation-default or server-default
profiles/           Functional suites — opt-in groups of core modules
modules/            Granular aspects — hardware, services, desktop, user
```

### Core (`modules/core/`)

These modules form the base security, networking, and system hygiene posture. They
are not imported directly by hosts; instead they are composed by `profiles/workstation`
and `profiles/server` under the names `workstation-default` and `server-default`.

| Module name | What it does |
|---|---|
| `core-boot` | LUKS initrd, kernel defaults, bootloader timeout |
| `core-networking` | NetworkManager, Tailscale, firewall, DNS |
| `core-security` | SSH, GPG, PKI certs, Polkit, PAM |
| `core-sysctl` | Kernel tuning (inotify, vm, net) |
| `core-users` | System user accounts and SSH keys |
| `core-zfs` | ZFS pool settings and ARC tuning via `nix-nexus.zfs.*` |

### Profiles (`profiles/`)

Profiles aggregate core modules into named role bundles:

- `workstation-default` — imports core-boot + core-networking + core-security +
  core-sysctl + core-users + core-zfs
- `server-default` — imports core-security + core-sysctl + core-users
  (omits boot, ZFS, and NM — containers manage these outside NixOS)
- `desktop-default` — greetd + Wayland + fonts + theming + kernel quiet/splash
- `development-default` — common system packages, Docker, custom scripts

### Modules (`modules/`)

Everything else. Hardware aspects, compositor configs, service stacks, user HM
profiles. Each file is a focused, opt-in capability fragment.

---

## Home Manager wiring

Home Manager integration for a NixOS host uses two additional fragments:

**`hosts/<hostname>/<user>-hm.nix`** — NixOS-side wiring. Registered as a
`flake.modules.nixos` entry. Configures the `home-manager` NixOS module and maps
a HM profile to a system user:

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
`flake.modules.homeManager.<hostname>-home`. Imports named HM modules and adds
host-specific overrides:

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
      ];
      programs.btop.package = pkgs.btop.override { rocmSupport = true; };
    };
}
```

---

## Standalone Home Manager (non-NixOS hosts)

For machines that run a foreign Linux (Debian, Armbian, etc.), one flake-parts
fragment maps every host for a given user. `modules/flake/hm-groot.nix` builds
`groot@dualie`, `groot@forge`, and `groot@rk3588` from a single host-to-system
table:

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

Activated with:
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

Modules can declare custom options in the `nix-nexus` namespace. The convention
is `nix-nexus.<subsystem>.<option>`:

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

Files under `lib/` are plain Nix expressions, not flake-parts fragments. They are
imported explicitly with a relative path where needed, not auto-discovered:

- `lib/custom-scripts.nix` — returns `{ pkgs }: { battery-alert = ...; system-stats = ...; }` 
- `lib/keymap.nix` — canonical multiplexer keymap plus `renderTmux` / `renderHerdr`;
  the single source both `programs.tmux` and herdr resolve their bindings from
- `lib/openclaude.nix` — npm package derivation
- `lib/avina/site-config.nix` — pure data attrset for avina domain constants

Do not place module logic in `lib/`. Do not place pure helper logic in `modules/`.
