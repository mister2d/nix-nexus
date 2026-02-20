{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # Basic configuration from the user's .vimrc
    extraConfig = ''
      " --- Basic Options ---
      set paste
      set bg=dark
      set expandtab
      set tabstop=2
      set shiftwidth=2

      " 'set number
      " 'set relativenumber

      " --- Navigation ---
      " Fast vertical navigation - 8 lines at a time
      nnoremap <C-j> 8j
      nnoremap <C-k> 8k
      vnoremap <C-j> 8j
      vnoremap <C-k> 8k

      " Half-page jumps with centered cursor
      nnoremap <C-d> <C-d>zz
      nnoremap <C-u> <C-u>zz

      " --- Tree-sitter Configuration ---
      " Enables advanced parsing and syntax highlighting for HCL and Nix.
      lua << EOF
      require'nvim-treesitter.configs'.setup {
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = {
          enable = true
        }
      }
      EOF
    '';

    # Plugins for syntax highlighting and parsing
    plugins = with pkgs.vimPlugins; [
      # Standard Nix support (indentation, etc.)
      vim-nix

      # Tree-sitter for modern parsing/highlighting
      (nvim-treesitter.withPlugins (p: [
        p.nix
        p.hcl
        p.terraform
        p.bash
        p.lua
        p.markdown
        p.vim
      ]))
    ];
  };
}
