# Permafrost microvm host module

`core-microvm-host` (`modules/core/microvm-host.nix`) prepares a NixOS host to
run permafrost microvm guests. It configures the bridge, NAT, kvm access, and
nested-virtualization policy. The permafrost runner (`nix run` of
`tenarches/nix-permafrost`) attaches its own guest taps to the bridge at
launch time.

## What core-microvm-host configures

- Creates the bridge interface named by `bridge.name` with no static member
  interfaces. The permafrost runner attaches taps to it at launch time.
- Assigns the host an IPv4 address on the bridge, from `bridge.address` and
  `bridge.prefixLength`.
- Excludes the bridge and any tap matching `tapPattern` from NetworkManager
  management, so NetworkManager does not fight the runner over the taps.
- Enables NAT masquerade on the bridge's internal interface. A null
  `externalInterface` masquerades on whichever interface carries the default
  route, so WiFi and a docked Ethernet both work.
- Sets `kvm_amd nested=0` through `boot.extraModprobeConfig`. The kernel
  reads this parameter only at module load. The sysfs file is read-only, so
  modprobe options are the only way to set the policy.
- Adds a udev rule that sets group `kvm` and mode `0660` on the `kvm`
  device. A second rule runs a check script on device creation. The script
  logs a warning if nested virtualization is on. Neither rule changes the
  kernel parameter.
- Installs `virtiofsd`, `bridge-utils` and `waypipe` on the host for
  virtiofs shares, bridge inspection and the fallback display transport.

## Options

All options live under `nix-nexus.virtualization.microvm.*`, declared in
`modules/core/microvm-host.nix`.

| Option | Type | Default | Purpose |
|---|---|---|---|
| `enable` | bool | `false` | Turns on the host side of the permafrost microvm sandbox. |
| `bridge.name` | str | `"microbr"` | Name of the bridge interface that carries permafrost guest taps. |
| `bridge.address` | str | `"192.168.33.1"` | IPv4 address the host holds on the microvm bridge. |
| `bridge.prefixLength` | int | `24` | Prefix length of the microvm bridge subnet. |
| `tapPattern` | str | `"microvm*"` | NetworkManager device-spec glob that matches the tap interfaces the permafrost runner creates. |
| `externalInterface` | null or str | `null` | Uplink interface for NAT masquerade. `null` follows the default route. |

The runner hardcodes the bridge name `microbr`, the gateway `192.168.33.1`,
the subnet `192.168.33.0/24` and the tap names `microvm-<id>`. Keep the
defaults of `bridge.name`, `bridge.address`, `bridge.prefixLength` and
`tapPattern` so the runner reuses the host bridge.

## Host consumer

`hosts/sweet16/default.nix` imports `nixosModules.core-microvm-host` and sets
`nix-nexus.virtualization.microvm.enable = true`. No other host in the fleet
imports this module.

## How the permafrost runner uses it

The permafrost runner looks for a bridge named `microbr`. That name is
hardcoded in the runner. It creates the bridge only when none exists, so
it reuses the bridge that `core-microvm-host` already brought up. Once a
tap device exists, the
runner attaches it to the bridge with `ip link set <tap> master <bridge>`.
The runner also adds its own iptables `POSTROUTING` MASQUERADE and
`FORWARD` rules for the guest subnet, idempotently, on every launch. Those
rules coexist with the NAT that `core-microvm-host` enables through
`networking.nat`. Both act on the same bridge subnet without conflict.

## Store settings in core-nix

`core-nix` (`modules/core/nix.nix`) sets three `nix.settings` values that
matter for a permafrost host:

- `auto-optimise-store = true` deduplicates identical store files with hard
  links. Dedup runs only on the host.
- `min-free = 5 GiB` triggers garbage collection during builds.
- `max-free = 20 GiB` bounds how much garbage collection reclaims once it
  starts.

A permafrost guest cannot set `auto-optimise-store` itself. microvm.nix
asserts that a writable store overlay and `auto-optimise-store` are
mutually exclusive. The host's Nix store is the guest's read-only lower
layer. The setting has to live on the host, in `core-nix`, not in any
guest module.

## Verification after a deploy

Run these checks on the deployed host after a rebuild:

- `ip link show microbr` shows the bridge up with the configured address.
- `nmcli device` lists `microbr` and any `microvm*` tap as unmanaged.
- `cat /sys/module/kvm_amd/parameters/nested` prints `0`.
- `nix config show auto-optimise-store` prints `true`.

## Why nix-nexus does not import the nix-permafrost flake

nix-nexus configures the host side of the permafrost sandbox directly in
`core-microvm-host`, rather than adding `tenarches/nix-permafrost` as a
flake input. Five reasons:

1. nix-permafrost's own host bridge module hardcodes the uplink interface
   name `wlp4s0`. sweet16's uplink differs, so the value would need an
   override at every import site.
2. nix-permafrost's host bridge module adds a `nix.settings.trusted-users`
   entry for a user named `agent`. That account does not exist on any
   nix-nexus host.
3. nix-permafrost's host module builds the bridge and tap attachment with
   `systemd-networkd`. `core-microvm-host` runs on a NetworkManager host
   and only excludes the bridge and taps from NetworkManager management.
4. nix-permafrost pulls a private `git+ssh` input (`agent-skills`, on a
   self-hosted Gitea). Adding `nix-permafrost` as a flake input locks that
   transitive input too. Every `nix flake check` and `nix flake lock` in
   this repository, including CI, would then need SSH access to that host.
5. nix-permafrost pins `nixos-unstable` for its main input and a second,
   older nixpkgs (`nixos-25.05`) for `crosvm`. That adds a second nixpkgs
   evaluation to a repository that otherwise tracks one channel.

`core-microvm-host` reimplements only the host-side surface nix-nexus
needs: the bridge, NAT, kvm access, and nested-virtualization policy, with
values that fit this fleet. It leaves the guest definitions to the
permafrost runner at launch time.
