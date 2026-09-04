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

      pin = import ../../lib/pinned-pkgs.nix { inherit pkgs; };

      # Versioned package helpers
      hashicorp-pkgs = pin.pinned inputs.pkgs-hashicorp;
      talos-pkgs = pin.pinned inputs.pkgs-talos;
      apps-pkgs = pin.pinned inputs.pkgs-apps;
      nomad-pkg = (pin.pinned inputs.pkgs-nomad).nomad;
      vault-pkg = hashicorp-pkgs.vault;
      consul-pkg = hashicorp-pkgs.consul;
      terraform-pkg = (pin.pinned inputs.pkgs-terraform).terraform;
      omnictl-pkg = talos-pkgs.omnictl;
      talosctl-pkg = talos-pkgs.talosctl;
      meld-pkg = apps-pkgs.meld;
      helm-pkg = hashicorp-pkgs.kubernetes-helm;
      butane-pkg = apps-pkgs.butane;
      envsubst-pkg = hashicorp-pkgs.envsubst;
      tflint-pkg = talos-pkgs.tflint;

      # Unstable Packages (for agents not in llm-agents or requiring latest unstable)
      unstable-pkgs = pin.pinnedWith [ self.overlays.buildFixes ] inputs.nixpkgs-unstable;

      # Kubernetes tools
      kubelogin-oidc-pkg = talos-pkgs.kubelogin-oidc;
      kubectl-rook-ceph-pkg = talos-pkgs.kubectl-rook-ceph;

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
