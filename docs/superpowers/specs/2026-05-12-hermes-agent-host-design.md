# Hermes Agent NixOS Host

## Summary

New NixOS host `hermes` — a Proxmox LXC container running the hermes-agent (v2026.5.7) from the `llm-agents` flake input. Cloned from the `openclaw` host skeleton, stripped to the minimal LXC base with the `groot` user. hermes-agent is installed as a user-scoped package via a locally scoped overlay in `flake.nix`.

## Files

### `hosts/hermes/default.nix`

System configuration cloned from openclaw's LXC skeleton:

- Imports: `proxmox-lxc.nix` module, `../../profiles/server` profile
- Proxmox LXC: unprivileged, unmanaged network
- Networking: hostname `hermes`, NetworkManager disabled, firewall disabled, systemd-networkd DHCP on eth0
- User `groot`: normal user, `kvm` group, bash shell, SSH ed25519 key
- Security: sudo disabled
- Services: resolved with caching, fstrim disabled
- Programs: tmux with vi keybindings
- State version: 25.11

Excludes all openclaw-specific concerns: HAProxy, Vault Agent, Tailscale, Matrix crypto workarounds, openclaw-secrets group, DNS delegation, insecure package permits.

### `hosts/hermes/home.nix`

Minimal home-manager module for groot:

- Imports shared modules: `bash.nix`, `terminal-home.nix`, `neovim-home.nix`
- No application-specific shell init (no NODE_PATH, no env file sourcing)

### `flake.nix` changes

New `nixosConfigurations.hermes` entry:

- `nixpkgs.lib.nixosSystem` with `system = "x86_64-linux"`
- Modules: buildFixesOverlay, llm-agents overlay (host-scoped), `./hosts/hermes/default.nix`, home-manager
- Overlay pattern (inline, scoped to hermes only):
  ```nix
  ({ pkgs, ... }: {
    nixpkgs.overlays = [
      (_final: _prev: {
        llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
      })
    ];
  })
  ```
- groot's `home.packages`: `pkgs.llm-agents.hermes-agent`, git, btop, htop, python314, nodejs_24, openssl

## Design decisions

- **Overlay scoped to host**: Follows avina's pinning pattern. Only hermes gets `pkgs.llm-agents.*`.
- **User-scoped package**: hermes-agent in `home.packages`, not `environment.systemPackages`. groot owns the agent lifecycle.
- **No service management**: User launches `hermes` manually. Systemd service, Vault, HAProxy, Tailscale, and Matrix integration deferred to future work.
- **Shared modules reused**: bash, terminal-home, neovim-home imported via home-manager, same as openclaw's groot user.
