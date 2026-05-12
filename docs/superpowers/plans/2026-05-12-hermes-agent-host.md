# Hermes Agent NixOS Host Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a new NixOS host `hermes` — a minimal Proxmox LXC container with the hermes-agent package available to the `groot` user.

**Architecture:** Clone the `openclaw` host's LXC skeleton (Proxmox base, systemd-networkd, groot user), strip all application-specific concerns, add a host-scoped overlay for `llm-agents` in `flake.nix`, and place `hermes-agent` in groot's `home.packages`.

**Tech Stack:** NixOS 25.11, home-manager, llm-agents.nix flake (hermes-agent v2026.5.7)

**Build host:** `ddukes@petunia.home.lan`
**Target host:** `root@hermes.home.lan`

---

### Task 1: Create `hosts/hermes/default.nix`

**Files:**
- Create: `hosts/hermes/default.nix`

- [ ] **Step 1: Create the hermes host directory**

```bash
mkdir -p hosts/hermes
```

- [ ] **Step 2: Write `hosts/hermes/default.nix`**

```nix
{
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../../profiles/server
  ];

  proxmoxLXC = {
    privileged = false;
    manageNetwork = false;
  };

  networking = {
    hostName = "hermes";
    networkmanager.enable = false;
    firewall.enable = false;
  };

  users.users.groot = {
    isNormalUser = true;
    extraGroups = [ "kvm" ];
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQp6H/n2JPSt1VxCAupTC1OTh7R3eu7wO0ZtCNbAkd7"
    ];
  };

  security.sudo.enable = false;

  systemd.network = {
    enable = true;
    networks."10-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig.DHCP = "yes";
    };
  };

  services = {
    resolved = {
      enable = true;
      extraConfig = ''
        Cache=true
        CacheFromLocalhost=true
      '';
    };

    fstrim.enable = false;
  };

  programs.tmux = {
    enable = true;
    shortcut = "a";
    baseIndex = 1;
    escapeTime = 0;
    keyMode = "vi";
    terminal = "tmux-256color";
    extraConfig = ''
      set -g status-style bg=black,fg=cyan
      set -g status-left "#[fg=cyan,bold] #S #[default]| "
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
    '';
  };

  system.stateVersion = "25.11";
}
```

- [ ] **Step 3: Commit**

```bash
git add hosts/hermes/default.nix
git commit -m "feat(hermes): add system configuration for LXC container"
```

---

### Task 2: Create `hosts/hermes/home.nix`

**Files:**
- Create: `hosts/hermes/home.nix`

- [ ] **Step 1: Write `hosts/hermes/home.nix`**

```nix
_: {
}
```

This is intentionally empty. The shared modules (bash, terminal-home, neovim-home) and nixvim are imported from the flake.nix home-manager block (same pattern as openclaw). Any hermes-specific home-manager config goes here later.

- [ ] **Step 2: Commit**

```bash
git add hosts/hermes/home.nix
git commit -m "feat(hermes): add home-manager configuration for groot"
```

---

### Task 3: Add `nixosConfigurations.hermes` to `flake.nix`

**Files:**
- Modify: `flake.nix:398-401` (insert before the closing braces of `nixosConfigurations`)

- [ ] **Step 1: Add the hermes configuration block**

Insert the following after the `openclaw` block (after line 400 `};`) and before the final closing `};` of `nixosConfigurations`:

```nix
        # Hostname: hermes (Proxmox LXC container — Hermes AI Agent)
        hermes = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs self;
          };
          modules = [
            # Global build fixes
            (_: {
              nixpkgs.overlays = [ self.buildFixesOverlay ];
              nixpkgs.config.allowUnfree = true;
            })

            # Main configuration entry point
            ./hosts/hermes/default.nix

            # Host-scoped overlay: make llm-agents packages available
            (
              { pkgs, ... }:
              {
                nixpkgs.overlays = [
                  (_final: _prev: {
                    llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
                  })
                ];
              }
            )

            # Home Manager configuration for groot
            home-manager.nixosModules.home-manager
            (
              { pkgs, ... }:
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  backupFileExtension = "bak";
                  extraSpecialArgs = {
                    inherit inputs self;
                  };
                  users.groot = {
                    home.stateVersion = "25.11";
                    home.packages = with pkgs; [
                      llm-agents.hermes-agent
                      nodejs_24
                      python314
                      git
                      btop
                      htop
                      openssl
                    ];
                    imports = [
                      inputs.nixvim.homeModules.nixvim
                      ./modules/user/bash.nix
                      ./modules/user/terminal-home.nix
                      ./modules/user/neovim-home.nix
                      ./hosts/hermes/home.nix
                    ];
                  };
                };
              }
            )
          ];
        };
```

- [ ] **Step 2: Run nix flake check to validate**

```bash
nix flake check --no-build 2>&1 | head -30
```

Expected: no errors related to hermes. Warnings about other hosts are acceptable.

- [ ] **Step 3: Commit**

```bash
git add flake.nix
git commit -m "feat(hermes): add nixosConfigurations.hermes with llm-agents overlay"
```

---

### Task 4: Build and deploy the hermes configuration

**Files:** None (build/deploy only)

- [ ] **Step 1: Build the hermes closure on petunia**

```bash
nixos-rebuild build --flake .#hermes 2>&1 | tail -20
```

Expected: successful build producing a `./result` symlink.

- [ ] **Step 2: Verify hermes-agent is in the closure**

```bash
nix path-info -r ./result | grep hermes-agent
```

Expected: a nix store path containing `hermes-agent-2026.5.7`.

- [ ] **Step 3: Deploy the closure to the target host**

```bash
nixos-rebuild switch --flake .#hermes --target-host root@hermes.home.lan --build-host localhost
```

Expected: successful activation on the remote host.

- [ ] **Step 4: Verify hermes is available on the target**

```bash
ssh groot@hermes.home.lan 'hermes --version'
```

Expected: version output from hermes-agent.

- [ ] **Step 5: Commit any lock file changes**

If `flake.lock` was updated during the build:

```bash
git add flake.lock
git commit -m "chore: update flake.lock for hermes build"
```
