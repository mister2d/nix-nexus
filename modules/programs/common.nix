{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    neovim
    vim
    wget
    curl
    git
    htop
    btop
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

    # Browsers
    google-chrome
    librewolf

    # Utilities
    pass
    gnupg
    pinentry-curses
    input-leap

    # Suite
    libreoffice
  ];
}
