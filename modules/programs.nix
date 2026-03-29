{
  lib,
  ...
}:
{

  den.aspects.programs-aspect = lib.mkForce {
    nixos =
      { pkgs, inputs, ... }:
      {
        nixpkgs.overlays = [ inputs.mcp-servers-nix.overlays.default ];

        environment.systemPackages = with pkgs; [
          # Core & Monitoring
          wget
          curl
          git
          pciutils
          usbutils
          lshw
          lm_sensors
          iotop
          htop
          ripgrep
          fd
          # File & Archive
          file
          tree
          unzip
          zip
          jq
          # Networking & Audio
          iw
          bind.dnsutils
          pulseaudio
          # Display & Browsers
          dmenu
          input-leap
          librewolf
          # Security
          pass
          gnupg
          pinentry-curses
          # Modern CLI & Productivity
          bat
          libreoffice
          # Development
          devbox
        ];

        virtualisation.docker = {
          enable = true;
          storageDriver = "zfs";
        };
      };
  };
}
