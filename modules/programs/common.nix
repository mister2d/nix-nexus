_: {
  flake.modules.nixos.development-default =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        # Core Connectivity & System Inspection
        wget
        curl
        git
        pciutils
        usbutils
        lshw
        lm_sensors
        iotop

        # Modern System Monitoring
        htop
        ripgrep
        fd

        # File & Archive Management
        file
        tree
        unzip
        zip
        jq

        # Networking & Audio Utilities
        iw
        bind.dnsutils
        pulseaudio

        # Display & Input Management
        dmenu
        input-leap

        # Browsers
        librewolf

        # Security & Secret Management
        pass
        gnupg
        pinentry-curses

        # Modern CLI Enhancements
        # These tools replace or augment traditional Unix utilities with faster,
        # more visual alternatives that respect modern terminal capabilities.
        bat # Syntax highlighting for 'cat'

        # Productivity Suite
        libreoffice
      ];
    };
}
