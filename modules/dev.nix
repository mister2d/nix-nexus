{
  inputs,
  lib,
  ...
}:
{
  # ============================================================================

  den.aspects.dev-aspect = lib.mkForce {
    homeManager =
      {
        pkgs,
        lib,
        config,
        ...
      }:
      let
        cfg = config.programs.dev-home;
        # Helper for versioned pins
        pin =
          input: pkg:
          (import inputs.${input} {
            inherit (pkgs.stdenv.hostPlatform) system;
            config.allowUnfree = true;
          }).${pkg};

        mcpPackages =
          if cfg.enableMcpServers then
            with pkgs;
            [
              context7-mcp
              github-mcp-server
              mcp-nixos
              mcp-server-fetch
              mcp-server-git
              mcp-server-sequential-thinking
              mcp-server-time
              terraform-mcp-server
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
          enable = lib.mkEnableOption "development home profile";
          enableMcpServers = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          enableLlmAgents = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
        };

        config = lib.mkIf cfg.enable {
          home.packages =
            with pkgs;
            [
              inputs.devenv.packages.${pkgs.stdenv.hostPlatform.system}.devenv
              devbox
              vscodium
              docker-compose
              uv
              (pin "pkgs-nomad" "nomad")
              (pin "pkgs-hashicorp" "vault")
              (pin "pkgs-hashicorp" "consul")
              (pin "pkgs-terraform" "terraform")
              (pin "pkgs-talos" "omnictl")
              (pin "pkgs-talos" "talosctl")
              (pin "pkgs-apps" "meld")
              (pin "pkgs-hashicorp" "kubernetes-helm")
              (pin "pkgs-apps" "butane")
              (pin "pkgs-hashicorp" "envsubst")
              (pin "pkgs-talos" "tflint")
              freelens-bin
              (pin "pkgs-talos" "kubelogin-oidc")
              (pin "pkgs-talos" "kubectl-rook-ceph")
              kubectl-doctor
            ]
            ++ mcpPackages
            ++ llmAgentPackages;

          programs.direnv = {
            enable = true;
            nix-direnv.enable = true;
          };

          programs.nixvim = {
            enable = true;
            defaultEditor = true;
            viAlias = true;
            vimAlias = true;
            opts = {
              background = "dark";
              expandtab = true;
              shiftwidth = 2;
              tabstop = 2;
              smartindent = true;
              number = false;
              relativenumber = false;
              cursorline = true;
              scrolloff = 8;
              termguicolors = true;
              mouse = "";
            };
            colorschemes.nightfox = {
              enable = true;
              flavor = "carbonfox";
            };
            keymaps = [
              {
                mode = "n";
                key = "<C-d>";
                action = "<C-d>zz";
              }
              {
                mode = "n";
                key = "<C-u>";
                action = "<C-u>zz";
              }
              {
                mode = [
                  "n"
                  "v"
                ];
                key = "<C-j>";
                action = "8j";
              }
              {
                mode = [
                  "n"
                  "v"
                ];
                key = "<C-k>";
                action = "8k";
              }
            ];
            plugins = {
              lsp = {
                enable = true;
                servers = {
                  nixd.enable = true;
                  terraformls.enable = true;
                  yamlls.enable = true;
                  jsonls.enable = true;
                  taplo.enable = true;
                  bashls.enable = true;
                };
              };
              cmp = {
                enable = true;
                settings = {
                  autoEnableSources = true;
                  sources = [
                    { name = "nvim_lsp"; }
                    { name = "path"; }
                    { name = "buffer"; }
                    { name = "luasnip"; }
                  ];
                  mapping = {
                    "C-Space" = "cmp.mapping.complete()";
                    "C-d" = "cmp.mapping.scroll_docs(-4)";
                    "C-f" = "cmp.mapping.scroll_docs(4)";
                    "C-e" = "cmp.mapping.close()";
                    "CR" = "cmp.mapping.confirm({ select = true })";
                    "Tab" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
                    "S-Tab" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
                  };
                };
              };
              cmp-nvim-lsp.enable = true;
              cmp-buffer.enable = true;
              cmp-path.enable = true;
              cmp_luasnip.enable = true;
              treesitter = {
                enable = true;
                settings = {
                  highlight.enable = true;
                  indent.enable = true;
                };
              };
              telescope.enable = true;
              lualine.enable = true;
              neo-tree.enable = true;
              gitsigns.enable = true;
              which-key.enable = true;
              web-devicons.enable = true;
            };
            extraPlugins = [ (pkgs.vimPlugins.vim-nomad or pkgs.vimPlugins.vim-nix) ];
          };
        };
      };
  };
}
