{
  description = "nix-nexus — fleet configuration for NixOS workstations, servers, and standalone Home Manager hosts";

  nixConfig = {
    extra-substituters = [
      "https://noctalia.cachix.org"
      "https://hyprland.cachix.org"
    ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  inputs = {
    # ── Core ────────────────────────────────────────────────────────────────
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

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
    # Hyprland upstream flake for v0.55.3. nixos-25.11 ships 0.52.1 which lacks
    # render.cm_auto_hdr. nixpkgs.follows reduces nixpkgs duplication; Hyprland's
    # sub-inputs (aquamarine, hyprlang, etc.) retain their own pinned nixpkgs.
    hyprland = {
      url = "github:hyprwm/Hyprland/v0.55.4";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    # inputs.nixpkgs.follows intentionally absent — required for the Noctalia Cachix binary cache.
    # See: https://docs.noctalia.dev/v5/getting-started/nixos/#binary-cache
    noctalia.url = "github:noctalia-dev/noctalia";

    # ── System ──────────────────────────────────────────────────────────────
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
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
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ── Pinned nixpkgs snapshots ─────────────────────────────────────────────
    # Each pin preserves a working version of one or more packages.
    pkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11"; # Matrix stack (avina)
    nixpkgs-chrome.url = "github:nixos/nixpkgs/fa56d7d6de78f5a7f997b0ea2bc6efd5868ad9e8"; # google-chrome
    pkgs-nomad.url = "github:nixos/nixpkgs/ae67888ff7ef9dff69b3cf0cc0fbfbcd3a722abe"; # nomad
    pkgs-hashicorp.url = "github:nixos/nixpkgs/a1bab9e494f5f4939442a57a58d0449a109593fe"; # vault consul helm envsubst ipmitool
    pkgs-terraform.url = "github:nixos/nixpkgs/7d2ae6d8b8b697b5114a4249d0d958ee5f23d8fe"; # terraform mqtt-explorer prusa-slicer
    pkgs-talos.url = "github:nixos/nixpkgs/ee09932cedcef15aaf476f9343d1dea2cb77e261"; # talosctl tflint omnictl signalbackup kubelogin-oidc kubectl-rook-ceph
    pkgs-vlc.url = "github:nixos/nixpkgs/41965737c1797c1d83cfb0b644ed0840a6220bd1"; # vlc
    pkgs-apps.url = "github:nixos/nixpkgs/f665af0cdb70ed27e1bd8f9fdfecaf451260fc55"; # meld butane
    pkgs-ceph.url = "github:nixos/nixpkgs/d1c15b7d5806069da59e819999d70e1cec0760bf"; # ceph
    # vivaldi-ffmpeg-codecs only. nixos-unstable pairs vivaldi 8.1 with the
    # prebuilt chromium-codecs-ffmpeg-extra 123075, which lacks
    # av_dynamic_hdr_smpte2094_app5_to_t35 and aborts vivaldi at startup.
    pkgs-vivaldi-codecs.url = "github:nixos/nixpkgs/3b32825de172d0bc85664f495edb096b10862524";
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
