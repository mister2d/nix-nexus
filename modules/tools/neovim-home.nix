_: {
  flake.modules.homeManager.user-neovim-home =
    { pkgs, lib, ... }:

    {
      programs.nixvim = {
        enable = true;
        defaultEditor = true;

        viAlias = true;
        vimAlias = true;

        # --- Core Options (The Nix Way) ---
        opts = {
          # Legacy behavior
          background = "dark";
          expandtab = true;
          shiftwidth = 2;
          tabstop = 2;
          smartindent = true;

          # Navigation & UI
          number = false; # Follows legacy preference
          relativenumber = false;
          cursorline = true;
          scrolloff = 8;
          termguicolors = true;

          # Mouse & Selection
          # By setting mouse to "a", we enable full mouse support in all modes.
          # We then map <RightMouse> to paste from the system clipboard.
          mouse = "a";
        };

        clipboard = {
          providers.wl-copy.enable = true;
        };

        # --- Keymaps (The Nix Way) ---
        colorschemes.nightfox = {
          enable = lib.mkDefault true;
          flavor = "carbonfox";
        };

        keymaps = [
          # Right-click to paste from system clipboard
          {
            mode = [
              "n"
              "v"
            ];
            key = "<RightMouse>";
            action = ''"+p'';
          }
          {
            mode = [
              "i"
              "c"
            ];
            key = "<RightMouse>";
            action = "<C-r>+";
          }

          # Legacy navigation
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

        # --- Plugins ---
        plugins = {
          # LSP Support for requested languages
          lsp = {
            enable = true;
            servers = {
              # Nix configuration
              nixd.enable = true;
              # HCL / Terraform / Nomad
              terraformls.enable = true;
              # Config formats
              yamlls.enable = true;
              jsonls.enable = true;
              taplo.enable = true; # TOML
              # Shell scripting
              bashls.enable = true;
            };
          };

          # Completion Engine
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

          # Modern Syntax Highlighting
          treesitter = {
            enable = true;
            settings = {
              highlight.enable = true;
              indent.enable = true;
            };
          };

          # Productivity & Modern Tools
          telescope.enable = true;
          lualine.enable = true;
          neo-tree.enable = true;
          gitsigns.enable = true;
          which-key.enable = true;
          web-devicons.enable = true;
        };

        # Custom logic for Nomad & K8s
        # We add these as extra plugins if they exist in nixpkgs,
        # or fallback to general HCL/LSP support.
        extraPlugins = with pkgs.vimPlugins; [
          # Standard syntax for Nomad
          (pkgs.vimPlugins.vim-nomad or pkgs.vimPlugins.vim-nix) # Fallback if not found
        ];

        extraConfigLua = ''
          -- Additional Lua config if needed
        '';
      };
    };
}
