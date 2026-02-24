{
  pkgs,
  inputs,
  ...
}:

let
  # Versioned package helpers
  nomad-pkg =
    (import inputs.pkgs-nomad {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).nomad;
  vault-pkg =
    (import inputs.pkgs-hashicorp {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).vault;
  consul-pkg =
    (import inputs.pkgs-hashicorp {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).consul;
  terraform-pkg =
    (import inputs.pkgs-terraform {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).terraform;
  omnictl-pkg =
    (import inputs.pkgs-talos {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).omnictl;
  talosctl-pkg =
    (import inputs.pkgs-talos {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).talosctl;
  meld-pkg =
    (import inputs.pkgs-apps {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).meld;
  helm-pkg =
    (import inputs.pkgs-hashicorp {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).kubernetes-helm;
  butane-pkg =
    (import inputs.pkgs-apps {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).butane;
  envsubst-pkg =
    (import inputs.pkgs-hashicorp {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).envsubst;
  tflint-pkg =
    (import inputs.pkgs-talos {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).tflint;

  # Kubernetes tools
  kubelogin-oidc-pkg =
    (import inputs.pkgs-talos {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).kubelogin-oidc;
  kubectl-rook-ceph-pkg =
    (import inputs.pkgs-talos {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).kubectl-rook-ceph;
in
{
  home.packages = with pkgs; [
    # --- Core Development Tools ---
    # These are high-level tools that don't depend on global interpreters.
    # Languages and interpreters should be managed via project-specific
    # flakes or dev shells with direnv.
    devbox
    uv
    vscodium
    docker-compose

    # --- MCP Servers ---
    context7-mcp
    mcp-nixos
    mcp-server-fetch
    mcp-server-git
    mcp-server-sequential-thinking
    mcp-server-time
    terraform-mcp-server

    # --- AI Coding Agents (Nix Native via llm-agents.nix) ---
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.gemini-cli
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.mcporter

    # --- Versioned Infrastructure Tools ---
    nomad-pkg
    vault-pkg
    consul-pkg
    terraform-pkg
    omnictl-pkg
    talosctl-pkg
    meld-pkg
    helm-pkg
    butane-pkg
    envsubst-pkg
    tflint-pkg
    freelens-bin

    # --- Kubernetes Tools ---
    kubelogin-oidc-pkg
    kubectl-rook-ceph-pkg
    kubectl-doctor
  ];
}
