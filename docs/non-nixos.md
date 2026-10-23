# Nix on Non-NixOS Hosts: Standalone Home Manager Guide

This guide describes how to use the `nix-nexus` framework on existing Linux
distributions (for example Debian, Ubuntu, or a locked-down work laptop)
with **Standalone Home Manager**. You keep a consistent, declarative user
environment without replacing the host operating system.

## 1. The Use Case: The Portable Workstation
You have a customized development environment (Bash aliases, Neovim
plugins, terminal themes) defined in `nix-nexus`. When you move to a new
machine, you can add that host to your Nix configuration. The machine can
be a Debian server or a corporate laptop you cannot wipe.

Nix manages your user-space tools and dotfiles. The host OS (kernel,
drivers, system services) stays untouched.

## 2. Bootstrapping the Host

### Install the Nix Package Manager
Install Nix in **multi-user mode**. This keeps the store isolated and secure.
```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

### Enable Experimental Features
Enable Flakes and the modern Nix CLI in `/etc/nix/nix.conf`:
```bash
experimental-features = nix-command flakes
```

### Use the internal binary cache
Add the cache and its public keys (the contents of `.secrets/cache.pub` and
`.secrets/builder.pub`) to `/etc/nix/nix.conf`, then restart `nix-daemon`:
```bash
extra-substituters = https://bincache.service.internal.novuscotia.com
extra-trusted-public-keys = <cache.pub> <builder.pub>
```
Home Manager cannot manage the daemon's `nix.conf`, so this stays manual.

#### Building and pushing from dualie

dualie also signs what it builds and pushes it to bincache. Home Manager
(`user-bincache-home`) provides the key through sops-nix and the hook script at
stable paths. The root daemon's `nix.conf` is manual:

1. Generate the age key as `groot` and send the public key line (`age1...`) to
   whoever maintains `.sops.yaml`: `mkdir -p ~/.config/sops/age && age-keygen -o ~/.config/sops/age/keys.txt`
   (use `nix shell nixpkgs#age`). Never share the file itself.
2. The maintainer adds it as a recipient for `secrets/common.yaml` in
   `.sops.yaml` and runs `sops updatekeys secrets/common.yaml`.
3. Apply the Home Manager config: `home-manager switch --flake .#groot@dualie`.
4. Keep the user manager running without a login session, so the key exists
   whenever a build runs: `sudo loginctl enable-linger groot`.
5. Add to `/etc/nix/nix.conf`, then `sudo systemctl restart nix-daemon`:
   ```
   substituters = https://bincache.service.internal.novuscotia.com https://cache.nixos.org
   trusted-public-keys = <cache.pub> <builder.pub> cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
   secret-key-files = /mnt/ironhide/home/groot/.config/sops-nix/secrets/builder-key
   post-build-hook = /mnt/ironhide/home/groot/.local/share/nix-nexus/bincache-push
   ```
   The key is a symlink into `$XDG_RUNTIME_DIR`. If the user manager is not running,
   the daemon cannot read it: `secret-key-files` then makes builds fail, and the
   hook logs "push failed". Linger (step 4) avoids both.

## 3. Adopting the Host into Nix-Nexus

### Define the Target
Add a `homeConfigurations` entry to your `flake.nix` for the new host:
```nix
homeConfigurations."user@hostname" = home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages."x86_64-linux";
  modules = [ ./hosts/<hostname>/home.nix ];
  extraSpecialArgs = { inherit inputs; };
};
```

### Create the Host Profile
Create a `home.nix` for the host (for example `hosts/dualie/home.nix`).
Import your preferred `nix-nexus` modules:
```nix
{ pkgs, ... }: {
  imports = [
    ../../modules/user/bash.nix
    ../../modules/user/neovim-home.nix
    ../../modules/user/devenv-home.nix
  ];
  home.username = "groot";
  home.homeDirectory = "/home/groot";
  home.stateVersion = "25.11";
}
```

## 4. Safe Migration: The "First Switch"
Existing hosts usually have their own `.bashrc` or `.profile`. Use the
**backup flag** on your first activation. This prevents Home Manager from
stopping on a file-clobber error:

```bash
nix run home-manager/release-26.05 -- switch --flake .#user@hostname -b bak
```

**What this does:**
- Renames your existing host files (for example `~/.bashrc` becomes `~/.bashrc.bak`).
- Symlinks your Nix-managed configuration into your home directory.
- The change survives reboots.

## 5. High-Performance AI & GPU Bridging
Nix-built binaries (like PyTorch or llama.cpp) expect libraries in the Nix
store. Your GPU drivers live in the host OS (for example
`/usr/lib/x86_64-linux-gnu`).

Use the **`llm-init`** tool from the `nix-devshell` flake to bridge this gap:
```bash
mkdir my-ai-project && cd my-ai-project
nix develop git+ssh://gitea@code-ssh.novuscotia.com/novuscotia-ops/nix-devshell#llm-agents --command llm-init
direnv allow
```
The generated environment maps your host's native NVIDIA drivers into your
isolated Nix shell. This gives full GPU acceleration for LLM workloads on
non-NixOS hosts.

## 6. Adapting to Older Hardware
Older servers (for example Ivy Bridge Xeons) lack modern instruction sets
like **AVX2**. The standalone profile installs no developer tooling, so
nothing here needs disabling. Call the `nix-devshell` shells only on hosts
that can run them. See [devshell.md](./devshell.md).
