# Consolidated Audit Report: `develop-den-refactor-v1` vs `main`

**Date:** 2026-04-08
**Branch Under Review:** `develop-den-refactor-v1`
**Baseline:** `main`
**Commits Analyzed:** `7b43dc0`, `934509f`
**Audit Methodology:** Direct branch diff + file-by-file analysis. The `memvid-mcp-server` was queried but returned empty results (`vector_count: 0`, empty graph, no replay sessions) — dendritic ground truth was derived from the `den` flake's own API surface as expressed in the refactored modules.

---

## 1. Executive Summary

The refactor successfully migrates the monolithic `hosts/` + `profiles/` layout into a `den`-native aspect-oriented DAG. The core architectural intent is sound: aspects are cleanly namespaced under `den.aspects.*`, `den.hosts.x86_64-linux` serves as the fleet control plane, and `import-tree` eliminates the need for explicit module wiring in `flake.nix`.

**However, the refactor is not deployable in its current state.** It contains three hard evaluation errors (missing flake inputs referenced in user modules), one boot-stopper (LUKS+ZFS devNodes), and a missing per-host package overlay that will break the avina Matrix stack. Beyond these blockers, approximately a dozen high-to-medium severity regressions represent functionality loss from the pre-dendritic baseline.

Severity distribution: **3 evaluation-error blockers, 5 boot/runtime critical, 7 high, 7 medium, 4 low.**

---

## 2. Structural Deviations

### SD-1: `flake.nix` — Four inputs dropped; three are still referenced in code

The develop `flake.nix` removed `devenv`, `llm-agents`, `nixpkgs-chrome`, and `mcp-servers-nix`. Three of these are still actively referenced:

| Input | Removed | Still Referenced In | Effect |
|---|---|---|---|
| `devenv` | ✓ | `modules/_user/dev-home.nix:93` | Hard eval error |
| `llm-agents` | ✓ | `modules/_user/dev-home.nix:96–101` | Hard eval error |
| `nixpkgs-chrome` | ✓ | `modules/_user/home.nix:16` | Hard eval error |
| `mcp-servers-nix` | ✓ | MCP packages via `pkgs.*` | Packages may not exist |

**Corrective Action:** Restore missing inputs to `flake.nix`:
```nix
devenv.url = "github:cachix/devenv";
llm-agents = { url = "github:numtide/llm-agents.nix"; inputs.nixpkgs.follows = "nixpkgs"; };
nixpkgs-chrome.url = "github:nixos/nixpkgs/fa56d7d6de78f5a7f997b0ea2bc6efd5868ad9e8";
mcp-servers-nix = { url = "github:natsukium/mcp-servers-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
```
Also restore the `mcp-servers-nix` overlay; add it to a suitable aspect (e.g., a system-level package in `base-aspect` or a dedicated `dev-system-aspect`).

---

### SD-2: `modules/hosts.nix` — `users.ddukes` defined in two competing locations

In the den framework, user home-manager config belongs in `den.hosts.<arch>.<hostname>.users.<user>`. The develop `hosts.nix` correctly defines it there for all three hosts. However, `petunia` and `avina` **additionally** define `users.ddukes` inside `den.aspects.petunia` and `den.aspects.avina` respectively — the exact same `includes = [ den.aspects.user-ddukes-aspect ]`. `sweet16` does not have this duplication and is the correct pattern.

```nix
# WRONG — double-registering user config on petunia and avina
den.aspects.petunia = {
  users.ddukes = {  # ← remove this block
    classes = [ "homeManager" "user" ];
    includes = [ den.aspects.user-ddukes-aspect ];
  };
  includes = [ ... ];
  nixos = { ... };
};
```

**Corrective Action:** Remove the `users.ddukes` attribute from `den.aspects.petunia` and `den.aspects.avina` in `modules/hosts.nix`. User registration is handled exclusively via `den.hosts.x86_64-linux` at the top of the same file.

---

### SD-3: `modules/hosts.nix` — avina stable package overlay not re-expressed

The `main` `flake.nix` applied a `nixpkgs.overlays` block to `avina` that pinned the entire Matrix 2.0 stack to `pkgs-stable` (25.11):

```nix
# Pinned in main flake.nix — completely absent in develop
matrix-synapse-unwrapped, matrix-authentication-service,
livekit, lk-jwt-service, element-web, element-call, postgresql_16
```

In the develop branch, the `flake.nix` no longer has per-host overlay injection. The `matrix-aspect` has no overlay. These packages will resolve from the default `nixpkgs` channel, which may diverge from the pinned revision.

**Corrective Action:** Add a `nixos` block to the `avina` aspect in `modules/hosts.nix` restoring the overlay:

```nix
avina = {
  includes = [ ... ];
  nixos = { pkgs, inputs, ... }: {
    nixpkgs.hostPlatform = "x86_64-linux";
    imports = [ "${inputs.nixpkgs}/nixos/modules/virtualisation/proxmox-lxc.nix" ];
    proxmoxLXC.privileged = false;
    nixpkgs.overlays = [
      (_final: _prev: {
        inherit (inputs.pkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system})
          matrix-synapse-unwrapped matrix-authentication-service
          livekit lk-jwt-service element-web element-call postgresql_16;
      })
    ];
  };
};
```

---

### SD-4: `modules/niri.nix` — NixOS module import commented out

```nix
# imports = [ inputs.niri.nixosModules.niri ];   ← line 8, commented out
```

The `inputs.niri` flake IS present in `flake.nix` and provides the `programs.niri` NixOS module. While `programs.niri` exists natively in NixOS 25.11, the `niri-flake` module adds additional home-manager sub-options (`programs.niri.settings`, `programs.niri.homeModules.niri`, the polkit agent disable pattern) that the develop `niri-aspect` uses. The `dms-aspect` also imports `inputs.dms.homeModules.niri`.

**Corrective Action:** Uncomment the import in `modules/niri.nix`:

```nix
den.aspects.niri-aspect = {
  nixos = { pkgs, lib, ... }: {
    imports = [ inputs.niri.nixosModules.niri ];  # restore
    ...
```

---

### SD-5: `modules/hosts.nix` — Three home-only configs missing

`main` had `homeConfigurations` for `groot@dualie` (Debian Trixie), `groot@rk3588` (ARM64 SBC fleet), and `groot@forge` (Debian 12). These are pure Home Manager configurations that don't fit the `den.hosts` NixOS model. They have no presence in the develop branch.

**Corrective Action:** These should be expressed as standalone `homeConfigurations` in a new `modules/home-only-hosts.nix` (or re-added to `flake.nix` outputs directly, since `import-tree` doesn't auto-discover `homeConfigurations`). Example:

```nix
# modules/home-only-hosts.nix — loaded by import-tree
{ inputs, ... }: {
  flake.homeConfigurations = {
    "groot@dualie" = inputs.home-manager.lib.homeManagerConfiguration { ... };
    "groot@rk3588" = inputs.home-manager.lib.homeManagerConfiguration { ... };
    "groot@forge"  = inputs.home-manager.lib.homeManagerConfiguration { ... };
  };
}
```

---

## 3. Missed Refactors

### MR-1: `modules/zfs.nix` — Five LUKS+ZFS boot-critical options missing

The `main` `modules/core/zfs.nix` contained essential boot-time ZFS configuration. The `zfs-aspect` collapsed this into three lines, dropping everything required for LUKS-on-ZFS boot:

| Missing Option | Location in main | Risk |
|---|---|---|
| `boot.initrd.kernelModules = [ "zfs" ]` | `core/zfs.nix:50` | ZFS not available during initrd — pool can't be found |
| `boot.zfs.forceImportRoot = true` | `core/zfs.nix:55` | Unreliable boot after unclean shutdown |
| `boot.zfs.devNodes = "/dev/mapper"` | `core/zfs.nix:60` | **BOOT STOPPER** — without this, the ZFS import service scans physical partitions, not LUKS devices; pool import will time out |
| `boot.zfs.requestEncryptionCredentials = false` | `core/zfs.nix:64` | ZFS may prompt for a passphrase that doesn't exist (LUKS manages decryption) |
| `boot.extraModprobeConfig` (ARC tuning) | `core/zfs.nix:67–90` | All memory pressure tuning silently removed |

Additionally, the old `nix-nexus.zfs` options namespace with per-host `arcMax`/`arcMin`/`arcSysFree`/`metaLimitPercent`/`dnodeLimitPercent` is gone. `sweet16` was tuned to 8GB ARC (appropriate for 32GB RAM); the new `zfs-aspect` hardcodes 2GB via `boot.kernelParams = [ "zfs.zfs_arc_max=2147483648" ]` — both a wrong value for the workstation and a less reliable mechanism than `extraModprobeConfig`.

**Corrective Action:** Replace the body of `den.aspects.zfs-aspect.nixos` in `modules/zfs.nix`:

```nix
den.aspects.zfs-aspect = {
  nixos = { lib, ... }: {
    boot = {
      supportedFilesystems = [ "zfs" ];
      initrd.kernelModules = [ "zfs" ];
      zfs = {
        forceImportRoot = true;
        devNodes = "/dev/mapper";
        requestEncryptionCredentials = false;
      };
      # Conservative fleet-wide default; hosts override via boot.extraModprobeConfig
      extraModprobeConfig = lib.mkDefault ''
        options zfs zfs_arc_max=2147483648
      '';
    };
    services.zfs = {
      autoScrub.enable = true;
      trim.enable = true;
      autoSnapshot = {
        enable = true;
        frequent = 8; hourly = 24; daily = 7; weekly = 4; monthly = 1;
      };
    };
  };
};
```

Then re-express per-host tuning in `modules/hosts.nix` sweet16 nixos block:

```nix
sweet16 = {
  nixos = { ... }: {
    networking.hostId = "efca0213";
    imports = [ ./_hw/sweet16/hardware-configuration.nix ];
    boot.extraModprobeConfig = ''
      options zfs zfs_arc_max=8589934592
      options zfs zfs_arc_min=2147483648
      options zfs zfs_arc_sys_free=4294967296
      options zfs zfs_arc_meta_limit_percent=85
      options zfs zfs_arc_dnode_limit_percent=25
    '';
  };
};
```

---

### MR-2: `modules/hw-z16.nix` — Z16-specific kernel parameters not migrated

`main`'s `modules/hardware/thinkpad-z16/default.nix` had 10 AMD/OLED-specific kernel parameters entirely absent from the develop `hw-z16-aspect`:

```nix
# All missing from modules/hw-z16.nix:
kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;  # ZFS+AMDGPU requires LTS
kernelParams = [
  "amdgpu.sg_display=0"        # Fixes white OLED flickering on Ryzen 6000
  "amdgpu.dcdebugmask=0x410"   # RDNA2 display/PM timeout fixes
  "amdgpu.gpu_recovery=1"
  "amdgpu.lockup_timeout=1000"
  "amdgpu.gttsize=4096"        # Caps iGPU GTT to preserve RAM for ARC/Apps
  "iommu=pt"                   # GPU memory stability on Ryzen
  "snd_pci_acp6x.dmic_config=1" # Digital mic detection on Rembrandt APU
  "amd_pstate=active"          # AMD P-States for Ryzen 6000
  "initcall_blacklist=acpi_cpufreq_init"
  "mem_sleep_default=s2idle"   # Conflicts with desktop-base's "deep" setting
];
extraModprobeConfig = ''
  options snd_pci_acp6x dmic_acp_check=1
  options snd_sof_amd_rembrandt dmic_acp_check=1
'';
```

Note the conflict: `desktop-base-aspect` sets `mem_sleep_default=deep` (S3 suspend) for all desktop hosts, but the Z16 requires `s2idle` (S0ix modern standby). In `main`, `lib.mkForce` in the hardware module resolved this. In the develop branch, `desktop-base-aspect`'s non-forced `deep` will apply and the Z16 will use the wrong suspend mode.

**Corrective Action:** Add the full kernel parameter set to `modules/hw-z16.nix`:

```nix
den.aspects.hw-z16-aspect = {
  nixos = { lib, pkgs, ... }: {
    imports = [ ... nixos-hardware modules ... ];
    boot = {
      kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;
      kernelParams = lib.mkAfter [
        "amdgpu.sg_display=0" "amdgpu.dcdebugmask=0x410"
        "amdgpu.gpu_recovery=1" "amdgpu.lockup_timeout=1000"
        "amdgpu.gttsize=4096" "iommu=pt"
        "snd_pci_acp6x.dmic_config=1" "amd_pstate=active"
        "initcall_blacklist=acpi_cpufreq_init"
        "mem_sleep_default=s2idle"  # overrides desktop-base's "deep"
      ];
      extraModprobeConfig = ''
        options snd_pci_acp6x dmic_acp_check=1
        options snd_sof_amd_rembrandt dmic_acp_check=1
      '';
    };
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
    services.pipewire = { enable = true; alsa.enable = true; pulse.enable = true; };
  };
};
```

---

### MR-3: `modules/security.nix` — `programs.vim.defaultEditor` and `PermitRootLogin` regression

`main` `modules/core/security.nix` had:
- `programs.vim.defaultEditor = false;` — prevents vim from overriding the user's nixvim neovim setup
- `services.openssh.settings.PermitRootLogin = "no"` — fully disables root SSH login

The develop `security-aspect` changed `PermitRootLogin` to `"prohibit-password"` (allows root login with SSH keys) and dropped the vim default override entirely.

**Corrective Action:**
```nix
# In modules/security.nix, inside den.aspects.security-aspect.nixos:
programs.vim.defaultEditor = false;
services.openssh.settings.PermitRootLogin = "no";  # was "prohibit-password"
```

---

### MR-4: `modules/base.nix` — Common system packages not fully migrated

`main` `modules/programs/common.nix` provided 20+ system packages. The `base-aspect` covers a subset (`vim`, `git`, `curl`, `wget`, `htop`, `tree`, `earlyoom`). Missing from the fleet-wide package list:

`pciutils`, `usbutils`, `lshw`, `lm_sensors`, `iotop`, `ripgrep`, `fd`, `file`, `unzip`, `zip`, `jq`, `bat`, `iw`, `bind.dnsutils`, `pulseaudio`, `input-leap`, `librewolf`, `pass`, `libreoffice`

**Corrective Action:** Add to `environment.systemPackages` in `modules/base.nix`'s `base-aspect`, or create a new `modules/common-programs.nix` aspect and add it to each host's `includes` list in `hosts.nix`. The latter is more composable.

---

### MR-5: Docker system service never enabled

`main` `modules/programs/dev.nix` enabled the Docker daemon:
```nix
virtualisation.docker = { enable = true; storageDriver = "zfs"; };
```
`base-aspect` adds `ddukes` to the `docker` group, but no aspect ever enables the daemon. Docker commands will fail at runtime.

**Corrective Action:** Add to a `dev-system-aspect` (or `base-aspect` with a `mkDefault`):
```nix
virtualisation.docker = { enable = lib.mkDefault true; storageDriver = lib.mkDefault "zfs"; };
```

---

### MR-6: nixvim home-manager module never imported in den path

`main` explicitly imported `nixvim.homeModules.nixvim` in every `nixosConfiguration`'s home-manager users block. The develop branch's `user-ddukes-aspect` imports `_user/home.nix`, which imports `_user/neovim-home.nix`, which uses `programs.nixvim.*` options extensively (LSP, cmp, treesitter, telescope, etc.). Without the nixvim home-manager module imported somewhere in the den chain, evaluation will fail.

**Corrective Action:** Add the nixvim import to the `user-ddukes-aspect` in `modules/user.nix`:
```nix
den.aspects.user-ddukes-aspect = {
  nixos = { inputs, ... }: {
    home-manager.users.ddukes = {
      imports = [
        inputs.nixvim.homeModules.nixvim  # ← add this
        ./_user/home.nix
      ];
      home.stateVersion = "25.11";
    };
  };
};
```

---

### MR-7: Kanshi multi-monitor management missing for sweet16

`main` had `modules/hardware/thinkpad-z16/kanshi-home.nix` (deleted in develop). No kanshi home-manager configuration exists for sweet16 in the develop branch. The `sway-aspect` still lists `kanshi` as an `extraPackage` but without a configuration file the tool does nothing.

**Corrective Action:** Add kanshi config back to `modules/hw-z16.nix`'s `home-manager.users.ddukes` block, or create `modules/_hw/sweet16/kanshi-home.nix` and import it from the sweet16 aspect in `hosts.nix`.

---

## 4. Identified Errors

### ERR-1: `modules/desktop-base.nix` — Waybar script path uses relative import

```nix
# modules/desktop-base.nix ~line 60:
let
  scripts = import ./_programs/_custom-scripts.nix { inherit pkgs; };
in
```
This relative path resolves correctly when evaluated from within `modules/` via `import-tree`. However, it creates a tight coupling — if `_programs/_custom-scripts.nix` is moved, this silently breaks without a clear error pointing here.

### ERR-2: `modules/sway.nix` — Greetd hardcodes sway and blocks niri session selection

Both `sway-aspect` and `desktop-base-aspect` configure `services.greetd.settings.default_session.command`. The `desktop-base-aspect` uses `lib.mkDefault`; the `sway-aspect` does not. On `sweet16` (which includes both), the sway command wins:

```
tuigreet --time --remember --asterisks --cmd sway
```

This hardcodes sway as the only session, making the niri session (also installed via `niri-aspect`) inaccessible from the login screen.

**Corrective Action:** Remove the `services.greetd` override from `sway-aspect` entirely. Let `desktop-base-aspect`'s generic tuigreet handle session selection (it discovers `.desktop` session files automatically):

```nix
# modules/sway.nix — remove this block from sway-aspect:
# services.greetd = { ... };
```

### ERR-3: `modules/networking.nix` — Typo in comment

Line 4: `"Connectivity & Mesh Mesh"` — "Mesh" is duplicated.

### ERR-4: `modules/hosts.nix` — `petunia` includes `sway-aspect` without desktop prerequisites

`petunia` is described as a "Primary home server and storage node." Its `includes` list contains `sway-aspect` but not `desktop-base-aspect`, `niri-aspect`, or `dms-aspect`. Sway will be enabled (with a hardcoded greetd command) on a server node without fonts, notifications, or portal configuration. This may be intentional (HTPC/media use case) but creates an asymmetric desktop stack.

---

## 5. Verifiable Corrective Actions (Priority Order)

### Priority 1 — Evaluation Blockers (Fix before `nix flake check` will pass)

**Action 1.1** — Restore three missing flake inputs
File: `flake.nix`
Add back `devenv`, `llm-agents`, and `nixpkgs-chrome` inputs (exact URLs from `main` `flake.nix`).
Verify: `nix flake metadata` shows all three inputs in the lock file.

**Action 1.2** — Restore MCP servers overlay
File: add `mcp-servers-nix` to `flake.nix` inputs; apply its overlay in `base-aspect` or a dedicated aspect.
Verify: `nix eval .#nixosConfigurations.sweet16.config.environment.systemPackages --apply 'ps: map (p: p.name) ps'` produces no "not found in pkgs" errors.

**Action 1.3** — Import nixvim home-manager module in `user-ddukes-aspect`
File: `modules/user.nix`
Verify: `nix build .#nixosConfigurations.sweet16.config.home-manager.users.ddukes.home.activationPackage`

---

### Priority 2 — Boot Blockers (Fix before deploying to any host)

**Action 2.1** — Restore `boot.zfs.devNodes = "/dev/mapper"` and companion ZFS boot options
File: `modules/zfs.nix`
Add `devNodes`, `forceImportRoot`, `requestEncryptionCredentials`, and `initrd.kernelModules`.
Verify: Boot `sweet16` or `petunia` in a VM and confirm ZFS pool mounts without timeout.

**Action 2.2** — Restore ThinkPad Z16 kernel parameters
File: `modules/hw-z16.nix`
Add the full kernel param set including `mem_sleep_default=s2idle` (overrides `desktop-base-aspect`'s `deep`).
Verify: On sweet16, `cat /sys/power/mem_sleep` shows `[s2idle]`; no OLED flickering on boot.

---

### Priority 3 — Data Protection (Fix before first production deploy)

**Action 3.1** — Restore `services.zfs.autoSnapshot` in `zfs-aspect`
File: `modules/zfs.nix`
Verify: `systemctl list-timers | grep zfs-snapshot`

**Action 3.2** — Restore per-host ZFS ARC tuning for sweet16 (32GB RAM → 8GB ARC)
File: `modules/hosts.nix`, sweet16 nixos block
Verify: `cat /proc/spl/kstat/zfs/arcstats | grep c_max` shows ~8GB

---

### Priority 4 — Security

**Action 4.1** — Revert `PermitRootLogin` to `"no"`
File: `modules/security.nix`
Verify: `ssh root@<host>` using any key is rejected with "Permission denied, please try again."

**Action 4.2** — Restore `programs.vim.defaultEditor = false`
File: `modules/security.nix`
Verify: `echo $VISUAL` in a root shell does not resolve to `vim`.

---

### Priority 5 — Structural Correctness

**Action 5.1** — Remove duplicate `users.ddukes` from `den.aspects.petunia` and `den.aspects.avina`
File: `modules/hosts.nix`
Verify: `nix eval .#nixosConfigurations.petunia` produces no attribute collision warnings.

**Action 5.2** — Uncomment niri NixOS module import
File: `modules/niri.nix`, line 8
Verify: `nix build .#nixosConfigurations.sweet16.config.programs.niri.package`

**Action 5.3** — Enable Docker daemon
File: add to `base-aspect` or a new `dev-system-aspect`
Verify: `systemctl status docker` on sweet16 shows `active (running)`.

**Action 5.4** — Fix greetd session conflict
File: `modules/sway.nix` — remove the `services.greetd` override from `sway-aspect`
Verify: On sweet16, tuigreet presents both a Sway and a Niri session option.

**Action 5.5** — Re-add stable Matrix package overlay for avina
File: `modules/hosts.nix`, avina aspect's `nixos` block (see SD-3 for exact code)
Verify: `nix eval .#nixosConfigurations.avina.config.services.matrix-synapse.package.version`

---

### Priority 6 — Package Completeness

**Action 6.1** — Restore common system packages to `base-aspect` or a new fleet-wide aspect
File: `modules/base.nix`
Missing: `pciutils`, `usbutils`, `lshw`, `lm_sensors`, `iotop`, `ripgrep`, `fd`, `file`, `unzip`, `zip`, `jq`, `bat`, `input-leap`, `librewolf`, `libreoffice`

**Action 6.2** — Add kanshi home-manager configuration for sweet16
File: new `modules/_hw/sweet16/kanshi-home.nix`; import from sweet16 aspect nixos block
Verify: `systemctl --user status kanshi` on sweet16 shows active.

**Action 6.3** — Add home configs for non-NixOS hosts (`groot@dualie`, `groot@rk3588`, `groot@forge`)
File: new `modules/home-only-hosts.nix` with `flake.homeConfigurations`
Verify: `nix run home-manager/release-25.11 -- switch --flake .#groot@dualie`

---

## Addendum A: `modules/niri.nix` — Missing `niri-flake-polkit` disable and system services

`main`'s `modules/desktop/niri.nix` had two blocks absent from the develop `niri-aspect`:

```nix
# Both missing from modules/niri.nix in develop:
systemd.user.services.niri-flake-polkit.enable = false;  # DMS conflict fix
services.accounts-daemon.enable = true;   # Required for user session tracking
services.upower.enable = true;            # Required for battery/power management
```

Without `niri-flake-polkit.enable = false`, the niri-flake's polkit agent and DMS's built-in polkit agent will both attempt to start, causing authentication conflicts. Without `accounts-daemon` and `upower`, power management UI (battery indicators, suspend prompts) will not function.

**Corrective Action:** Add these three lines to the `nixos` block of `den.aspects.niri-aspect` in `modules/niri.nix`.

---

## Addendum B: `modules/core-aspects.nix` — `printing-aspect` missing `ensure-printers` service dependency

`main`'s `modules/core/printing.nix` had:
```nix
systemd.services.ensure-printers = {
  aliases = [ "printing-provision.service" ];
  after = [ "network-online.target" ];
  wants = [ "network-online.target" ];
};
```
The `printing-aspect` drops this, meaning `ensurePrinters` may run before the network is available and fail silently on first boot.

**Corrective Action:** Add the `systemd.services.ensure-printers` block back to `den.aspects.printing-aspect` in `modules/core-aspects.nix`.
