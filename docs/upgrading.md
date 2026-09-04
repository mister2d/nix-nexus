# Upgrading nix-nexus

This guide explains how to keep the fleet current. It covers routine
within-release updates and full major-release upgrades. It applies
specifically to this flake-based repository.

The [official NixOS upgrading reference](https://nixos.org/manual/nixos/stable/#sec-upgrading)
covers the traditional channel-based workflow. The flake approach here
differs in the mechanics. It follows the same principles.

---

## How NixOS releases work

NixOS follows a biannual release cycle, named by year and month:

| Channel | Type | Use case |
|---|---|---|
| `nixos-26.05` | Stable | Conservative bug fixes and security patches only |
| `nixos-25.11` | Stable (previous) | Previous stable release, still supported |
| `nixos-unstable` | Rolling | Main development branch; bleeding edge |
| `nixos-25.11-small` | Stable (previous, server) | Same as the previous stable with fewer pre-built binaries |

**Stable releases** receive only conservative bug fixes and minor package
upgrades. They exclude major version jumps in core software.
`nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05"` tracks this branch.

**Unstable** reflects the development branch. It may include radical changes
between updates. nix-nexus uses `nixpkgs-unstable` selectively, currently for
petunia's AI/ML stack and tool inputs that need cutting-edge packages.

---

## How flake inputs replace channels

In a traditional NixOS setup, `nix-channel --add` subscribes to a channel
URL. `nixos-rebuild switch --upgrade` fetches it.

In this flake repository, `flake.nix` inputs serve the same role. The
channel is encoded in the input URL. `flake.lock` pins the exact commit:

```nix
# This is the flake equivalent of subscribing to nixos-26.05:
nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
```

`nix flake update` is the flake equivalent of `nix-channel --update`.
`nixos-rebuild switch --flake .#hostname` applies the result.

---

## Input categories in this flake

Know which inputs to update and which inputs to leave alone.

### Category 1 — Release-tracked inputs (update together on upgrade)

These inputs follow the current stable release branch. Bump them together
when you upgrade to a new NixOS release:

| Input | Current URL | Notes |
|---|---|---|
| `nixpkgs` | `github:nixos/nixpkgs/nixos-26.05` | Primary stable nixpkgs |
| `pkgs-stable` | `github:nixos/nixpkgs/nixos-25.11` | Pinned separately for the avina Matrix stack |
| `home-manager` | `github:nix-community/home-manager/release-26.05` | HM must match nixpkgs release |
| `nixvim` | `github:nix-community/nixvim/nixos-26.05` | nixvim must match nixpkgs release |

### Category 2 — Unstable-tracked inputs (update independently)

These inputs follow the nixos-unstable branch. They have no tie to the
stable release cycle. Update them separately at any time:

| Input | Current URL |
|---|---|
| `nixpkgs-unstable` | `github:nixos/nixpkgs/nixos-unstable` |
| `home-manager-unstable` | `github:nix-community/home-manager/master` |

### Category 3 — Tool inputs (update opportunistically)

These inputs have no hard release coupling. Update them when you need new
features or bug fixes from them:

`flake-parts`, `import-tree`, `devenv`, `pre-commit-hooks`, `nixos-hardware`,
`mcp-servers-nix`, `llm-agents`, `niri`, `hyprland`, `dms`, `disko`,
`nix-cachyos-kernel`

### Category 4 — Intentionally pinned inputs (do NOT update without review)

These inputs pin to specific nixpkgs commits to lock particular package
versions. Before you update one, verify the target version is still
available at the new commit. Update the inline comment too:

| Input | Pinned for |
|---|---|
| `pkgs-nomad` | nomad |
| `pkgs-hashicorp` | vault, consul, helm, envsubst, ipmitool |
| `pkgs-terraform` | terraform, mqtt-explorer, prusa-slicer, super-slicer |
| `pkgs-talos` | talosctl, tflint, omnictl, signalbackup, kubelogin-oidc, kubectl-rook-ceph |
| `pkgs-vlc` | vlc |
| `pkgs-apps` | meld, butane |
| `pkgs-ceph` | ceph |
| `nixpkgs-chrome` | google-chrome (specific version) |

See `docs/packages.md` for the pinned version details.

---

## Routine updates (within-release)

Use this procedure to pull the latest packages on the current stable
branch. This includes security patches, bug fixes, and minor package
updates. It does not change the release.

### 1. Pull latest commits for all non-pinned inputs

```bash
# Update all inputs except intentionally pinned ones:
nix flake update nixpkgs pkgs-stable home-manager home-manager-unstable \
  nixpkgs-unstable nixvim flake-parts import-tree devenv pre-commit-hooks \
  nixos-hardware mcp-servers-nix llm-agents niri dms disko \
  nix-cachyos-kernel

# Or update everything at once (includes pinned — review the diff carefully):
nix flake update
```

### 2. Review the lock file diff

```bash
git diff flake.lock
```

Check that `nixpkgs` moved to a newer commit on the same branch. Check that
no pinned inputs shifted unexpectedly.

### 3. Deploy to each host

```bash
# NixOS hosts:
nixos-rebuild switch --flake .#sweet16
nixos-rebuild switch --flake .#petunia

# For remote NixOS hosts (LXC containers, servers):
nixos-rebuild switch --flake .#avina --target-host root@avina
nixos-rebuild switch --flake .#hermes --target-host root@hermes

# Standalone Home Manager (non-NixOS):
nix run home-manager/release-26.05 -- switch --flake .#groot@dualie -b bak
nix run home-manager/release-26.05 -- switch --flake .#groot@forge -b bak
nix run home-manager/release-26.05 -- switch --flake .#groot@rk3588 -b bak
```

### 4. Commit the updated lock file

```bash
git add flake.lock
git commit -m "chore(flake): update inputs — nixos-26.05 $(date +%Y-%m-%d)"
```

---

## Major release upgrade (e.g., 25.11 → 26.05)

NixOS major releases ship roughly every May and November. This procedure
upgrades the entire fleet to a new stable branch.

> **Before starting:** Read the NixOS release notes for the target version at
> `https://nixos.org/manual/nixos/stable/release-notes`. Note any breaking
> changes, renamed options, or modules that need configuration updates.

### 1. Update release-tracked inputs in `flake.nix`

Open `flake.nix`. Update every URL that contains the current release tag.
Find all occurrences of the old release string:

```bash
grep -n "25\.11" flake.nix
```

Update each one to the new release. For a `25.11 → 26.05` upgrade:

```nix
# Before:
nixpkgs.url      = "github:nixos/nixpkgs/nixos-25.11";
pkgs-stable.url  = "github:nixos/nixpkgs/nixos-25.11";
home-manager.url = "github:nix-community/home-manager/release-25.11";
nixvim.url       = "github:nix-community/nixvim/nixos-25.11";

# After:
nixpkgs.url      = "github:nixos/nixpkgs/nixos-26.05";
pkgs-stable.url  = "github:nixos/nixpkgs/nixos-26.05";
home-manager.url = "github:nix-community/home-manager/release-26.05";
nixvim.url       = "github:nix-community/nixvim/nixos-26.05";
```

> **Important:** Home Manager releases must match the nixpkgs release they
> are paired with. Mismatched versions cause evaluation errors.

### 2. Fetch the new lock file

```bash
nix flake update nixpkgs pkgs-stable home-manager nixvim
```

This resolves the new branch heads. It writes them to `flake.lock`. The
intentionally pinned inputs, such as `pkgs-nomad` and `pkgs-hashicorp`,
stay untouched.

### 3. Evaluate the full tree

```bash
nix flake check
```

This evaluates every host configuration. Common failures on a major upgrade:

- **Renamed options**: a NixOS module changed structure. Check the release
  notes. Update the option path in the relevant module file.
- **Removed packages**: a package was renamed or moved. Use the
  `nixos-tools` MCP (`action: search, query: <package>`) to find the new
  attribute path.
- **Home Manager version mismatch**: if `home-manager.url` still points to
  the old release branch, update it. See step 1.

Fix all evaluation errors before proceeding.

### 4. Deploy to one host first

Test the upgrade on the least critical host before rolling out fleet-wide:

```bash
nixos-rebuild switch --flake .#hermes --target-host root@hermes
```

Verify the host comes up cleanly. Check for service failures:

```bash
ssh root@hermes systemctl --failed
```

### 5. Deploy remaining hosts

Once you confirm the host works, roll out to all remaining hosts. Deploy
workstations before production servers:

```bash
nixos-rebuild switch --flake .#sweet16
nixos-rebuild switch --flake .#petunia
nixos-rebuild switch --flake .#avina   --target-host root@avina
nixos-rebuild switch --flake .#hermes  --target-host root@hermes
```

Standalone HM hosts use the new release branch in the `nix run` invocation:

```bash
nix run home-manager/release-26.05 -- switch --flake .#groot@dualie -b bak
nix run home-manager/release-26.05 -- switch --flake .#groot@forge -b bak
nix run home-manager/release-26.05 -- switch --flake .#groot@rk3588 -b bak
```

### 6. Commit the upgrade

```bash
git add flake.nix flake.lock
git commit -m "chore(flake): upgrade NixOS 25.11 → 26.05"
```

---

## Rollback

### Boot-time rollback (recommended for broken boots)

NixOS keeps all previous system generations in the GRUB or systemd-boot
menu. If the new generation fails to boot, or breaks a critical service,
reboot and select a prior generation from the boot menu. No data is lost.
The previous system closure stays fully intact on disk.

### In-session rollback

If the system booted but the running configuration is broken:

```bash
nixos-rebuild switch --rollback
```

This activates the previous generation without a reboot. Use
`boot --rollback` instead if you want the rollback to persist across
reboots.

### Flake-level rollback

To revert `flake.lock` to a previous state:

```bash
git checkout HEAD~1 -- flake.lock
nix flake update   # re-reads the reverted lock
nixos-rebuild switch --flake .#hostname
```

### Channel downgrade caveat

From the official NixOS manual:

> It is generally safe to switch back and forth between channels. The only
> exception is that a newer NixOS may also have a newer Nix version, which
> may involve an upgrade of Nix's database schema. This cannot be undone
> easily, so in that case you will not be able to go back to your original
> channel.

In practice, downgrading from unstable or a newer stable release to an
older stable release can require a Nix store schema rebuild. This applies
after Nix itself was upgraded. Avoid downgrading across major Nix version
boundaries.

---

## Automatic upgrades (optional)

NixOS provides a `system.autoUpgrade` service for unattended updates.
For a flake-based system, point it at the flake path:

```nix
# In a host's NixOS module (e.g., hosts/hermes/default.nix):
{
  system.autoUpgrade = {
    enable      = true;
    flake       = "/path/to/nix-nexus#hermes";
    allowReboot = true;   # reboot automatically if kernel/initrd changed
  };
}
```

When `allowReboot = false`, the service runs `nixos-rebuild switch` on the
current lock file at the scheduled interval. When `allowReboot = true`, the
service also reboots if the new generation includes a different kernel,
initrd, or kernel module set.

Check when the service is scheduled to run:

```bash
systemctl list-timers nixos-upgrade.timer
```

> **Note:** Auto-upgrade with a flake activates the currently locked inputs.
> It does not run `nix flake update` automatically. To pull new package
> versions, update `flake.lock` in the repository manually, or via CI, and
> push the change. The auto-upgrade service then applies whatever lock file
> is present at the configured path.

---

## Quick reference

| Task | Command |
|---|---|
| Update inputs (within release) | `nix flake update <input-names>` |
| Update all inputs | `nix flake update` |
| Check full tree evaluates | `nix flake check` |
| Deploy local NixOS host | `nixos-rebuild switch --flake .#<hostname>` |
| Deploy remote NixOS host | `nixos-rebuild switch --flake .#<hostname> --target-host root@<hostname>` |
| Deploy standalone HM host | `nix run home-manager/release-<YY.MM> -- switch --flake .#<user>@<hostname> -b bak` |
| Roll back current host | `nixos-rebuild switch --rollback` |
| List generations | `nix-env --list-generations --profile /nix/var/nix/profiles/system` |
| Show which channel/branch is pinned | `grep nixpkgs.url flake.nix` |
