# Nix on Non-NixOS Hosts: Standalone Home Manager Guide

This guide describes how to leverage the `nix-nexus` framework on existing Linux distributions (e.g., Debian, Ubuntu, or locked-down work laptops) using **Standalone Home Manager**. This allows developers to maintain a consistent, declarative user environment without replacing the host operating system.

## 1. The Use Case: The Portable Workstation
You have a highly customized development environment (Bash aliases, Neovim plugins, terminal themes) defined in `nix-nexus`. When you move to a new machine—whether it's a Debian server or a corporate laptop you cannot wipe—you can "adopt" that host into your Nix configuration. 

Nix will manage your user-space tools and dotfiles while leaving the host OS (Kernel, Drivers, System Services) untouched.

## 2. Bootstrapping the Host

### Install the Nix Package Manager
Install Nix in **multi-user mode** to keep the store isolated and secure.
```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

### Enable Experimental Features
Ensure Flakes and the modern Nix CLI are enabled in `/etc/nix/nix.conf`:
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
Create a `home.nix` for the host (e.g., `hosts/dualie/home.nix`) that imports your preferred `nix-nexus` modules:
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
Existing hosts usually have their own `.bashrc` or `.profile`. To prevent Home Manager from aborting due to "clobbering" errors, use the **backup flag** during your first activation:

```bash
nix run home-manager/release-26.05 -- switch --flake .#user@hostname -b bak
```

**What this does:**
- Renames your existing host files (e.g., `~/.bashrc` -> `~/.bashrc.bak`).
- Symlinks your Nix-managed configuration into your home directory.
- This migration is **durable**: your new environment persists across reboots.

## 5. High-Performance AI & GPU Bridging
Nix-built binaries (like PyTorch or llama.cpp) expect libraries in the Nix store, but your GPU drivers live in the host OS (e.g., `/usr/lib/x86_64-linux-gnu`).

Use the **`llm-init`** tool provided in the `dev-home` profile to bridge this gap:
```bash
mkdir my-ai-project && cd my-ai-project
llm-init
direnv allow
```
The generated environment dynamically maps your host's native NVIDIA drivers into your isolated Nix shell, enabling full GPU acceleration for LLM workloads on non-NixOS hosts.

## 6. Adapting to Older Hardware
If you are deploying to older servers (e.g., Ivy Bridge Xeons) that lack modern instruction sets like **AVX2**, you can selectively disable heavy workstation tools while keeping your core shell environment:

```nix
nix-nexus.user.dev = {
  enable = true;
  enableMcpServers = false; # Disables packages requiring AVX2
  enableLlmAgents = false;  # Disables packages requiring modern instructions
};
```
