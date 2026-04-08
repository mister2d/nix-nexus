{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

with lib;

let
  cfg = config.programs.dev-home;

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

  # Project-level CUDA environment generator
  inherit ((import ../programs/_custom-scripts.nix { inherit pkgs; })) llm-init;

  mcpPackages =
    if cfg.enableMcpServers then
      [
        pkgs.context7-mcp
        pkgs.github-mcp-server
        pkgs.mcp-nixos
        pkgs.mcp-server-fetch
        pkgs.mcp-server-git
        pkgs.mcp-server-sequential-thinking
        pkgs.mcp-server-time
        pkgs.terraform-mcp-server
      ]
    else
      [ ];

  llmAgentPackages =
    if cfg.enableLlmAgents then
      [
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.gemini-cli
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.mcporter
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.rtk
      ]
    else
      [ ];
in
{
  options.programs.dev-home = {
    enable = mkEnableOption "development home profile";
    enableMcpServers = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install MCP servers (may fail on older CPUs lacking AVX2).";
    };
    enableLlmAgents = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install AI Coding Agents (e.g. opencode, gemini-cli).";
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        # --- Core Development Tools ---
        # Devenv 2.0 is the primary engine for declarative project environments.
        # We retain 'devbox' and 'docker-compose' for legacy project interoperability.
        inputs.devenv.packages.${pkgs.stdenv.hostPlatform.system}.devenv
        devbox
        vscodium
        docker-compose
        llm-init
        uv

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
      ]
      ++ mcpPackages
      ++ llmAgentPackages;

    # Direnv integration for automatic environment loading
    programs.direnv = {
      enable = true;
      # Enables the faster, Nix-optimized implementation of direnv
      nix-direnv.enable = true;
    };
  };
}
