# Cookbook: Common Operations

This document gives step-by-step recipes for the most frequent tasks. Each
recipe shows the **minimum number of files** to create or edit. Each recipe
gives a working example from the actual codebase.

Read [architecture.md](./architecture.md) first if you are not yet familiar
with how fragments, registries, and host assemblies relate to each other.

---

## Table of contents

1. [Add a NixOS system module](#1-add-a-nixos-system-module)
2. [Add a Home Manager module](#2-add-a-home-manager-module)
3. [Add a new system user](#3-add-a-new-system-user)
4. [Add an application stack (multi-file service group)](#4-add-an-application-stack)
5. [Add a new NixOS host (workstation)](#5-add-a-new-nixos-host-workstation)
6. [Add a new NixOS host (server / LXC)](#6-add-a-new-nixos-host-server--lxc)
7. [Add a standalone Home Manager host (non-NixOS)](#7-add-a-standalone-home-manager-host-non-nixos)

---

## 1. Add a NixOS system module

**When to use:** Add a new system-level capability (a service, a kernel
setting, a package group). One or more hosts opt into it by name.

### Step 1 — Create the fragment

Choose the right subdirectory under `modules/`:

| Capability | Directory |
|---|---|
| Core OS policy (networking, security, boot) | `modules/core/` |
| Hardware-specific (GPU, sensors, firmware) | `modules/hardware/` |
| Desktop (compositor, display manager) | `modules/desktop/` |
| User-facing programs and scripts | `modules/programs/` |
| Long-running services | `modules/services/<stackname>/` |

Pick a kebab-case name. Follow the
[naming conventions](./architecture.md#naming-conventions).

```nix
# modules/services/syncthing.nix
_: {
  flake.modules.nixos.services-syncthing =
    { pkgs, lib, ... }:
    {
      services.syncthing = {
        enable   = true;
        user     = "ddukes";
        dataDir  = "/home/ddukes";
        configDir = "/home/ddukes/.config/syncthing";
      };
      networking.firewall.allowedTCPPorts = [ 8384 22000 ];
      networking.firewall.allowedUDPPorts = [ 22000 21027 ];
    };
}
```

This is the entire file. import-tree discovers it automatically. Add no
wiring in `flake.nix` or anywhere else.

### Step 2 — Import it in the host

Open the relevant host module under `hosts/<hostname>/default.nix`. Add the
name to the `imports` list:

```nix
# hosts/sweet16/default.nix (excerpt)
imports = [
  nixosModules.workstation-default
  nixosModules.desktop-default
  nixosModules.development-default
  nixosModules.services-syncthing   # ← add this line
];
```

### Step 3 — Apply

```bash
nixos-rebuild switch --flake .#sweet16
```

### Validating before switching

```bash
nix flake check       # evaluates all hosts
nix build .#nixosConfigurations.sweet16.config.system.build.toplevel
```

---

## 2. Add a Home Manager module

**When to use:** Add user-level configuration (dotfiles, packages, services).
One or more users opt into it by name.

### Step 1 — Create the fragment

```nix
# modules/user/starship-home.nix
_: {
  flake.modules.homeManager.user-starship-home =
    { pkgs, ... }:
    {
      programs.starship = {
        enable = true;
        settings = {
          add_newline = false;
          character = {
            success_symbol = "[➜](bold green)";
            error_symbol   = "[➜](bold red)";
          };
        };
      };
    };
}
```

### Step 2 — Import it in a host HM profile

Add the name to the `imports` list of the relevant
`hosts/<hostname>/home.nix`:

```nix
# hosts/sweet16/home.nix (excerpt)
_: {
  flake.modules.homeManager.sweet16-home =
    { homeManagerModules, ... }:
    {
      imports = [
        homeManagerModules.user-home
        homeManagerModules.hardware-z16-hypr-home
        homeManagerModules.desktop-hyprland-home
        homeManagerModules.user-starship-home    # ← add this line
      ];
    };
}
```

### Step 3 — Apply

```bash
# If the user is managed via NixOS home-manager module:
nixos-rebuild switch --flake .#sweet16

# If the user is a standalone HM config:
home-manager switch --flake .#groot@dualie -b bak
```

---

## 3. Add a new system user

There are two layers. The **NixOS account** is the system user record. The
optional **Home Manager profile** holds dotfiles and packages.

### 3a — NixOS account only (simplest, host-specific)

For a user that appears on only one host, declare it directly in the host
module:

```nix
# hosts/myserver/default.nix
_: {
  flake.modules.nixos.myserver-default =
    { pkgs, nixosModules, ... }:
    {
      imports = [ nixosModules.server-default ];

      users.users.alice = {
        isNormalUser = true;
        extraGroups  = [ "wheel" ];
        shell        = pkgs.bash;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAA... alice@laptop"
        ];
      };

      networking.hostName = "myserver";
      system.stateVersion = "25.11";
    };
}
```

### 3b — Shared user across multiple hosts (module approach)

For a user that spans several machines, create a dedicated module. This keeps
the account managed in one place:

```nix
# modules/core/alice.nix
_: {
  flake.modules.nixos.core-alice =
    { pkgs, ... }:
    {
      users.users.alice = {
        isNormalUser = true;
        extraGroups  = [ "networkmanager" "wheel" "video" "audio" "docker" ];
        shell        = pkgs.bash;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAA... alice@laptop"
        ];
      };
    };
}
```

Then import it wherever needed:

```nix
# hosts/<hostname>/default.nix
imports = [
  nixosModules.workstation-default
  nixosModules.core-alice           # ← pulled in by name
];
```

### 3c — Add Home Manager for the new user (NixOS-managed)

**File 1:** The NixOS wiring fragment. It bridges HM into the NixOS system.

```nix
# hosts/<hostname>/alice-hm.nix
_: {
  flake.modules.nixos.hm-alice-myhostname =
    { inputs, homeManagerModules, ... }:
    {
      home-manager = {
        useGlobalPkgs       = true;
        useUserPackages     = true;
        backupFileExtension = "bak";
        extraSpecialArgs    = {
          inherit (inputs) self;
          inherit inputs homeManagerModules;
        };
        users.alice.imports = [
          homeManagerModules.myhostname-alice-home
        ];
      };
    };
}
```

**File 2:** The HM profile for this user on this host.

```nix
# hosts/<hostname>/alice-home.nix
_: {
  flake.modules.homeManager.myhostname-alice-home =
    { pkgs, homeManagerModules, ... }:
    {
      imports = [
        homeManagerModules.user-bash
        homeManagerModules.user-neovim-home
      ];

      home = {
        stateVersion = "25.11";
        packages = with pkgs; [ git htop ];
      };

      programs.home-manager.enable = true;
    };
}
```

**Step 3:** Wire the HM NixOS module into the flake assembly.

```nix
# modules/flake/nixos-myhostname.nix
{ inputs, config, ... }:
let
  hm    = config.flake.modules.homeManager;
  nixos = config.flake.modules.nixos;
in
{
  flake.nixosConfigurations.myhostname = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      inherit (inputs) self;
      nixosModules       = nixos;
      homeManagerModules = hm;
    };
    modules = [
      nixos.overlays-global
      nixos.myhostname-default
      inputs.home-manager.nixosModules.home-manager
      nixos.hm-alice-myhostname       # ← the wiring fragment
    ];
  };
}
```

---

## 4. Add an application stack

**When to use:** A service spans multiple concerns (versions pinning, core
service, database, reverse proxy). Split it across several files for
readability. The `deferredModule` type **merges** all files that register
the same name automatically. No aggregator file is needed.

The `services-matrix` stack (nine files, one name) is the existing model.

### Step 1 — Create a directory for the stack

```
modules/services/mystack/
```

### Step 2 — Create one file per concern, all using the same name

```nix
# modules/services/mystack/versions.nix
_: {
  flake.modules.nixos.services-mystack =
    { pkgs, ... }:
    let
      myapp-pkg = pkgs.myapp.overrideAttrs (_: { version = "2.1.0"; });
    in
    {
      environment.systemPackages = [ myapp-pkg ];
    };
}
```

```nix
# modules/services/mystack/backend.nix
_: {
  flake.modules.nixos.services-mystack =
    { config, lib, ... }:
    {
      services.myapp = {
        enable    = true;
        port      = 8080;
        secretFile = "/run/secrets/myapp-key";
      };
      systemd.services.myapp.after = [ "postgresql.service" ];
    };
}
```

```nix
# modules/services/mystack/database.nix
_: {
  flake.modules.nixos.services-mystack = _: {
    services.postgresql = {
      enable     = true;
      ensureDatabases = [ "myapp" ];
      ensureUsers = [{
        name              = "myapp";
        ensureDBOwnership = true;
      }];
    };
  };
}
```

All three files register `services-mystack`. The module system merges the
three NixOS module functions. A host that imports
`nixosModules.services-mystack` receives `versions.nix` + `backend.nix` +
`database.nix` combined.

### Step 3 — Import the stack in the target host

```nix
# hosts/myserver/default.nix
imports = [
  nixosModules.server-default
  nixosModules.services-mystack    # ← one name, three merged modules
];
```

### Optional: keep one module standalone (not merged)

A part of the stack can be optional (an add-on bridge, a sidecar service).
Give it a **distinct name** so it stays independently selectable:

```nix
# modules/services/mystack/whatsapp-bridge.nix
_: {
  flake.modules.nixos.services-mystack-whatsapp = _: {
    # not merged into services-mystack — hosts that want it import it separately
    services.mautrix-whatsapp.enable = true;
  };
}
```

---

## 5. Add a new NixOS host (workstation)

A workstation has a hardware scan, hardware modules, and a user. It can also
have a desktop and a Home Manager configuration.

### Files to create

```
hosts/<hostname>/default.nix            # host NixOS module
hosts/<hostname>/hardware-configuration.nix  # generated at install time
hosts/<hostname>/home.nix               # HM profile (optional)
hosts/<hostname>/<user>-hm.nix         # HM NixOS wiring (optional)
modules/flake/nixos-<hostname>.nix      # flake assembly
```

### Step 1 — Generate hardware configuration on the target machine

```bash
nixos-generate-config --show-hardware-config > hosts/<hostname>/hardware-configuration.nix
```

Wrap the output as a self-registering fragment:

```nix
# hosts/<hostname>/hardware-configuration.nix
_: {
  flake.modules.nixos.<hostname>-hardware = _: {
    # paste the output of nixos-generate-config here
    boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" ];
    fileSystems."/" = { device = "/dev/disk/by-uuid/..."; fsType = "ext4"; };
    # ...
  };
}
```

### Step 2 — Create the host module

```nix
# hosts/<hostname>/default.nix
_: {
  flake.modules.nixos.<hostname>-default =
    { nixosModules, ... }:
    {
      imports = [
        nixosModules.<hostname>-hardware   # from hardware-configuration.nix
        nixosModules.workstation-default   # core policies
        nixosModules.desktop-default       # greetd, Wayland, fonts, theming
        nixosModules.development-default   # dev tools, Docker, scripts
        nixosModules.desktop-hyprland      # compositor
      ];

      networking.hostName = "<hostname>";
      networking.hostId   = "<8 hex chars>";   # required for ZFS: head -c4 /dev/urandom | xxd -p

      system.stateVersion = "25.11";
    };
}
```

### Step 3 — Create the Home Manager profile (optional)

```nix
# hosts/<hostname>/home.nix
_: {
  flake.modules.homeManager.<hostname>-home =
    { homeManagerModules, ... }:
    {
      imports = [
        homeManagerModules.user-home
        homeManagerModules.desktop-hyprland-home
        homeManagerModules.desktop-noctalia-home
      ];
      home.stateVersion = "25.11";
    };
}
```

### Step 4 — Create the HM NixOS wiring (if using Home Manager)

```nix
# hosts/<hostname>/ddukes-hm.nix
_: {
  flake.modules.nixos.hm-ddukes-<hostname> =
    { inputs, homeManagerModules, ... }:
    {
      home-manager = {
        useGlobalPkgs       = true;
        useUserPackages     = true;
        backupFileExtension = "bak";
        extraSpecialArgs    = {
          inherit (inputs) self;
          inherit inputs homeManagerModules;
        };
        users.ddukes.imports = [
          homeManagerModules.<hostname>-home
        ];
      };
    };
}
```

### Step 5 — Create the flake assembly

```nix
# modules/flake/nixos-<hostname>.nix
{ inputs, config, ... }:
let
  hm    = config.flake.modules.homeManager;
  nixos = config.flake.modules.nixos;
in
{
  flake.nixosConfigurations.<hostname> = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      inherit (inputs) self;
      nixosModules       = nixos;
      homeManagerModules = hm;
    };
    modules = [
      nixos.overlays-global
      nixos.<hostname>-default
      inputs.home-manager.nixosModules.home-manager
      nixos.hm-ddukes-<hostname>
    ];
  };
}
```

### Step 6 — Install and apply

```bash
# On the target machine after booting the NixOS installer:
nixos-install --flake .#<hostname>

# Subsequent updates from the machine itself:
nixos-rebuild switch --flake .#<hostname>
```

---

## 6. Add a new NixOS host (server / LXC)

Servers use `server-default` instead of `workstation-default`. LXC
containers import `modulesPath + "/virtualisation/proxmox-lxc.nix"`. LXC
containers disable features that Proxmox manages externally (networking,
hostname).

### Files to create

```
hosts/<hostname>/default.nix
modules/flake/nixos-<hostname>.nix
```

No hardware scan is needed for LXC. The Proxmox host provides the kernel and
hardware.

### `hosts/<hostname>/default.nix`

```nix
_: {
  flake.modules.nixos.<hostname>-default =
    {
      pkgs,
      modulesPath,
      nixosModules,
      ...
    }:
    {
      imports = [
        (modulesPath + "/virtualisation/proxmox-lxc.nix")
        nixosModules.server-default
        # add service stacks here, e.g.:
        # nixosModules.services-mystack
      ];

      proxmoxLXC = {
        privileged    = false;
        manageNetwork = false;   # Proxmox manages the veth
      };

      networking = {
        hostName             = "";            # Proxmox sets this at runtime
        networkmanager.enable = false;
        firewall.enable      = false;         # firewall is on the Proxmox bridge
      };

      systemd.network = {
        enable = true;
        networks."10-eth0" = {
          matchConfig.Name = "eth0";
          networkConfig.DHCP = "yes";
        };
      };

      services.resolved.enable = true;

      system.stateVersion = "25.11";
    };
}
```

### `modules/flake/nixos-<hostname>.nix`

```nix
{ inputs, config, ... }:
let
  hm    = config.flake.modules.homeManager;
  nixos = config.flake.modules.nixos;
in
{
  flake.nixosConfigurations.<hostname> = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      inherit (inputs) self;
      nixosModules       = nixos;
      homeManagerModules = hm;
    };
    modules = [
      nixos.overlays-global
      nixos.<hostname>-default
    ];
  };
}
```

### Deploying to an LXC

```bash
# Build the system closure and push to the container
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel
nix copy --to ssh://root@<lxc-ip> .#nixosConfigurations.<hostname>.config.system.build.toplevel

# Or deploy directly with nixos-rebuild on the container
nixos-rebuild switch --flake .#<hostname> --target-host root@<lxc-ip>
```

---

## 7. Add a standalone Home Manager host (non-NixOS)

**When to use:** The machine runs Debian, Ubuntu, Armbian, or any other Linux
not managed by NixOS. Home Manager is the only Nix-managed layer.

### Files to create

```
hosts/<hostname>/home.nix             # HM profile
modules/flake/hm-<user>.nix           # standalone HM config, one file per user
```

The user might already have a standalone HM assembly file (for example
`modules/flake/hm-groot.nix`, which maps `dualie`, `forge`, and `rk3588`). If
so, add the new host to that file's host-to-system attrset. Do not create a
new file.

### `hosts/<hostname>/home.nix`

```nix
# hosts/mydebian/home.nix
_: {
  flake.modules.homeManager.mydebian-home =
    {
      pkgs,
      inputs,
      homeManagerModules,
      ...
    }:
    {
      imports = [
        homeManagerModules.user-bash
        homeManagerModules.user-neovim-home
        homeManagerModules.user-terminal-home
        homeManagerModules.user-dev-home
      ];

      home = {
        username      = "alice";
        homeDirectory = "/home/alice";
        stateVersion  = "25.11";

        packages = with pkgs; [ git curl wget jq ripgrep ];
      };

      programs.home-manager.enable = true;

      # Standalone HM configs manage their own allowUnfree
      nixpkgs.config.allowUnfree = true;
    };
}
```

### `modules/flake/hm-alice.nix`

One file per user maps every one of that user's standalone hosts. Follow the
pattern in `modules/flake/hm-groot.nix` (which maps `dualie`, `forge`, and
`rk3588`). `flake.homeConfigurations` is `lazyAttrsOf raw`. One fragment may
set several `"user@host"` keys with `lib.mapAttrs'`.

```nix
{
  inputs,
  config,
  lib,
  ...
}:
let
  hm = config.flake.modules.homeManager;
  hosts = {
    mydebian = "x86_64-linux";
  };
in
{
  # Usage: nix run home-manager/release-26.05 -- switch --flake .#alice@mydebian -b bak
  flake.homeConfigurations = lib.mapAttrs' (
    host: system:
    lib.nameValuePair "alice@${host}" (
      inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        modules = [ hm."${host}-home" ];
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

Adding a second standalone host for the same user is one more line in
`hosts`. It is not a new file.

### Activate

```bash
# First time (bootstraps home-manager itself):
nix run home-manager/release-26.05 -- switch --flake .#alice@mydebian -b bak

# Subsequent updates (once home-manager is on PATH):
home-manager switch --flake .#alice@mydebian -b bak
```

> **Note on architecture:** `flake.homeConfigurations` uses `lib.types.raw`,
> not `deferredModule`. Each `"user@host"` key must be set by exactly one
> fragment. One fragment may set several keys, as `modules/flake/hm-groot.nix`
> does. A single key still cannot be split across multiple files.

---

## Quick-reference: which file does what

| Task | File(s) to create or edit |
|---|---|
| Add system capability | `modules/<category>/<name>.nix` |
| Add HM capability | `modules/user/<name>-home.nix` or `modules/desktop/<name>-home.nix` |
| Enable capability on a host | `hosts/<hostname>/default.nix` — add to `imports` |
| Enable HM capability on a host | `hosts/<hostname>/home.nix` — add to `imports` |
| Add multi-file service stack | `modules/services/<stack>/*.nix` (all same name) |
| Add new NixOS host | `hosts/<hostname>/default.nix` + `modules/flake/nixos-<hostname>.nix` |
| Add new standalone HM host | `hosts/<hostname>/home.nix` + `modules/flake/hm-<user>.nix` (e.g. `modules/flake/hm-groot.nix`) |
| Add HM for a user on NixOS | `hosts/<hostname>/<user>-hm.nix` + `hosts/<hostname>/<user>-home.nix` |

---

## Troubleshooting

### "attribute 'my-module-name' missing" at evaluation

The name you referenced in `nixosModules.my-module-name` does not exist in
the registry. Possible causes:

1. **Typo in the name** — the key in `flake.modules.nixos.` must match
   exactly.
2. **File not in a discovered tree** — the file must be under `modules/`,
   `hosts/`, or `profiles/`. import-tree does not discover files in `lib/`.
3. **File has a `_` in its path** — import-tree skips paths containing `/_`.

To list all currently registered names:

```bash
nix eval --json .#nixosModules | nix run nixpkgs#jq -- 'keys'
```

### Pre-commit hooks fail on a new file

Run linters on the specific file before committing:

```bash
.agents/scripts/preflight.sh modules/services/mystack/backend.nix
```

The runner is `prek`, not `pre-commit`. See
[workflow.md](./workflow.md#step-3--lint).

The three linters are `nixfmt-rfc-style` (formatting), `deadnix` (unused
bindings), and `statix` (anti-patterns). Fix all failures before committing.
The CI gate requires all three to pass.

### "error: infinite recursion" when using `config.*` inside a module

Within a flake-parts fragment, the outer `config` is the **flake-parts**
config, not the NixOS config. Inside a NixOS module value, the NixOS-level
`config` is available only if you include it in the NixOS module's argument
set. The NixOS module value is the function assigned to
`flake.modules.nixos.<name>`:

```nix
# WRONG — config here is flake-parts config
{ config, ... }: {
  flake.modules.nixos.my-module = _: {
    networking.firewall.allowedTCPPorts = [ config.services.myapp.port ];
  };
}

# CORRECT — bring config from the NixOS module argument set
_: {
  flake.modules.nixos.my-module =
    { config, ... }:    # ← this config is the NixOS config
    {
      networking.firewall.allowedTCPPorts = [ config.services.myapp.port ];
    };
}
```
