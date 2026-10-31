{
  description = "nix-nexus — fleet configuration for NixOS workstations, servers, and standalone Home Manager hosts";

  inputs = {
    # ── Core ────────────────────────────────────────────────────────────────
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    # herdr — terminal multiplexer with coding-agent session awareness.
    # Pinned to a tagged release and built from its own flake rather than
    # through nixpkgs, so it tracks the upstream release independently of
    # the nixpkgs-unstable input. rust-overlay is a herdr sub-input and
    # follows nixpkgs.
    herdr = {
      url = "github:herdrdev/herdr/v0.9.3";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # ── Home Manager ────────────────────────────────────────────────────────
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-unstable = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # ── Desktop ─────────────────────────────────────────────────────────────
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Pinned to a tagged release. Unlike other inputs, main is not tracked here.
    # It can carry unreviewed nix-packaging changes ahead of a release.
    # inputs.nixpkgs.follows intentionally absent — required for the Noctalia Cachix binary cache.
    # See: https://docs.noctalia.dev/v5/getting-started/nixos/#binary-cache
    noctalia.url = "github:noctalia-dev/noctalia/v5.0.1";

    # ── Theming ─────────────────────────────────────────────────────────────
    # Two branches, mirroring the home-manager/home-manager-unstable dual-track
    # idiom above. sweet16 pins nixpkgs 26.05 + home-manager release-26.05.
    # petunia tracks nixpkgs-unstable + home-manager master.
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix-unstable = {
      url = "github:nix-community/stylix"; # master
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # ── System ──────────────────────────────────────────────────────────────
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    # RDNA4 GPU platform modules (amdgpu, ROCm sysroot, dual-GPU, limits).
    rdna4 = {
      url = "github:tenarches/nix-rdna4";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        flake-parts.follows = "flake-parts";
      };
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── Development tooling ─────────────────────────────────────────────────
    devenv.url = "github:cachix/devenv";
    # Required by devenv's flakeModule container plumbing even when unused.
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    nixvim.url = "github:nix-community/nixvim/nixos-26.05";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Developer tooling (overlays, modules, devShells). Consumed by hermes only;
    # every other host calls its devShells on demand. See docs/devshell.md.
    nix-devshell = {
      url = "git+ssh://gitea@code-ssh.novuscotia.com/novuscotia-ops/nix-devshell";
      inputs = {
        nixpkgs-unstable.follows = "nixpkgs-unstable";
        flake-parts.follows = "flake-parts";
        import-tree.follows = "import-tree";
      };
    };

    # pi-durable harness NixOS module. Consumed by petunia (services-pi-durable).
    pi-durable = {
      url = "git+ssh://gitea@code-ssh.novuscotia.com/novuscotia-ops/pi-durable";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        flake-parts.follows = "flake-parts";
        import-tree.follows = "import-tree";
      };
    };

    # Bifrost HTTPS front door NixOS module. Consumed by petunia (services-bifrost-front-door).
    nix-bifrost = {
      url = "git+ssh://gitea@code-ssh.novuscotia.com/novuscotia-ops/nix-bifrost.git?ref=edge-followups";
      inputs = {
        flake-parts.follows = "flake-parts";
        import-tree.follows = "import-tree";
      };
    };

    # ── Pinned nixpkgs snapshots ─────────────────────────────────────────────
    # Each pin preserves a working version of one or more packages.
    pkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11"; # Matrix stack (avina)
    nixpkgs-chrome.url = "github:nixos/nixpkgs/fa56d7d6de78f5a7f997b0ea2bc6efd5868ad9e8"; # google-chrome
    # hyprland 0.57.0 + xdph 1.5.0 from nixpkgs PR #580006; drop once it reaches nixos-unstable.
    nixpkgs-hyprland.url = "github:NixOS/nixpkgs/ca053bb97d1d25b09242b30afe974fffc55737c3";
  };

  outputs =
    inputs:
    let
      # Fleet-wide module tree. To add a new subtree, append its path here only.
      fleet = builtins.foldl' (it: p: it.addPath p) inputs.import-tree [
        ./modules
        ./hosts
        ./profiles
      ];
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } fleet.result;
}
