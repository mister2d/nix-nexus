{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    wget
    curl
    git
    htop
    pciutils
    usbutils
    lshw
    ripgrep
    fd
    file
    tree
    unzip
    zip
    jq
    iw
    bind.dnsutils
    dmenu
    pulseaudio

    # Browsers
    librewolf

    # Utilities
    pass
    gnupg
    pinentry-curses
    input-leap

    # Modern CLI Enhancements
    # These tools replace or augment traditional Unix utilities with faster,
    # more visual alternatives that respect modern terminal capabilities.
    bat # Syntax highlighting for 'cat'

    # Suite
    libreoffice
  ];
}
