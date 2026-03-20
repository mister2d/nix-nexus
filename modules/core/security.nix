{ pkgs, ... }:

{
  security = {
    rtkit.enable = true;
    polkit.enable = true;

    # Custom Certificate Authority
    # Place your int_cert.crt in the 'certs' directory at the root of the repo
    pki.certificateFiles = [
      ../../certs/int_cert.crt
    ];
  };

  # System Services
  services = {
    # Secret Service for password management (required for ProtonVPN, etc.)
    gnome.gnome-keyring.enable = true;

    # Hardware-based Authentication (Yubikey & FIDO2)
    pcscd.enable = true; # Smartcard daemon for Yubikey
    udev.packages = [ pkgs.yubikey-personalization ]; # Udev rules for hardware access

    # Secure Remote Access (OpenSSH)
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false; # Secure by default, use keys
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };

  programs = {
    # File System Permissions
    # Enable FUSE for unprivileged mounting
    fuse.userAllowOther = true;

    # System Integration
    # Enable dconf (required for EasyEffects and GTK portals)
    dconf.enable = true;

    # Secret & Key Management
    # The GPG Agent is configured to provide both OpenPGP and SSH agent services.
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
      pinentryPackage = pkgs.pinentry-curses;

      # Session Caching
      # Extended TTL settings reduce the frequency of authentication prompts
      # during long working sessions.
      settings = {
        default-cache-ttl = 28800; # 8 hours
        max-cache-ttl = 86400; # 24 hours
        default-cache-ttl-ssh = 28800; # 8 hours
        max-cache-ttl-ssh = 86400; # 24 hours
      };
    };
  };

  # Editor Environment
  # Disable vim as the default editor to prevent overlaps with custom neovim profiles.
  programs.vim.defaultEditor = false;

  # Privilege Escalation
  security.sudo = {
    # security.sudo.wheelNeedsPassword = false;
    extraConfig = ''
      Defaults env_keep += "EDITOR VISUAL SUDO_EDITOR"
    '';
  };
}
