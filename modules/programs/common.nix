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

    # Suite
    libreoffice
  ];
}
