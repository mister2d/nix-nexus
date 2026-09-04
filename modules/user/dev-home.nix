_: {
  flake.modules.homeManager.user-dev-home =
    {
      pkgs,
      lib,
      config,
      inputs,
      self,
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

      # Unstable Packages (for agents not in llm-agents or requiring latest unstable)
      unstable-pkgs = import inputs.nixpkgs-unstable {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
        # Apply our build fixes to unstable as well
        overlays = [ self.overlays.buildFixes ];
      };

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
      inherit ((import ../../lib/custom-scripts.nix { inherit pkgs; })) llm-init;

      openclaude-pkg = import ../../lib/openclaude.nix { inherit pkgs lib; };

      # Model Control Protocol (MCP) servers
      mcpPackages =
        if cfg.enableMcpServers then
          [
            pkgs.context7-mcp
            pkgs.github-mcp-server
            unstable-pkgs.mcp-nixos
            pkgs.mcp-server-time
            pkgs.terraform-mcp-server
          ]
        else
          [ ];

      # AI Coding Agents
      # Hybrid approach: latest versions from llm-agents, supplemented by unstable nixpkgs.
      llmAgentPackages =
        let
          agentPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
        in
        if cfg.enableLlmAgents then
          [
            # From llm-agents (Latest)
            agentPkgs.claude-code
            agentPkgs.antigravity-cli
            agentPkgs.opencode
            agentPkgs.pi # v0.70.2 > unstable v0.67

            # From unstable nixpkgs (Exclusives or specific versions)
            unstable-pkgs.opencode-desktop
            unstable-pkgs.opencode-claude-auth

            openclaude-pkg
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
          description = "Whether to install MCP servers.";
        };
        enableLlmAgents = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to install AI Coding Agents.";
        };
      };

      config = mkIf cfg.enable {
        home.packages =
          with pkgs;
          [
            # --- Core Development Tools ---
            inputs.devenv.packages.${pkgs.stdenv.hostPlatform.system}.devenv
            devbox
            vscodium
            docker-compose
            llm-init
            uv
            nodejs_24

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
          nix-direnv.enable = true;
        };
      };
    };
}
