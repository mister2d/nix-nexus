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
    ../../modules/user/dev-home.nix
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

Use the **`llm-init`** tool from the `dev-home` profile to bridge this gap:
```bash
mkdir my-ai-project && cd my-ai-project
llm-init
direnv allow
```
The generated environment maps your host's native NVIDIA drivers into your
isolated Nix shell. This gives full GPU acceleration for LLM workloads on
non-NixOS hosts.

## 6. Adapting to Older Hardware
When you deploy to older servers (for example Ivy Bridge Xeons) without
modern instruction sets like **AVX2**, you can disable heavy workstation
tools and keep your core shell environment:

```nix
nix-nexus.user.dev = {
  enable = true;
  enableMcpServers = false; # Disables packages requiring AVX2
  enableLlmAgents = false;  # Disables packages requiring modern instructions
};
```
