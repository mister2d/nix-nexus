# Merged into: flake.modules.nixos.desktop-default
# Configures: Nerd Fonts and base font packages for every desktop host.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.desktop-default =
    { pkgs, ... }:
    {
      fonts.packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        liberation_ttf
        fira-code
        fira-code-symbols
        mplus-outline-fonts.githubRelease
        dina-font
        proggyfonts
        # Individual Nerd Fonts (25.11 standard)
        pkgs.nerd-fonts.jetbrains-mono
        pkgs.nerd-fonts.fira-code
        pkgs.nerd-fonts.symbols-only
      ];
    };
}
