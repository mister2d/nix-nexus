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

  programs = {
    # Enable FUSE for unprivileged mounting
    fuse.userAllowOther = true;

    # Enable dconf (required for EasyEffects and GTK portals)
    dconf.enable = true;

    # Enable GPG Agent
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
      pinentryPackage = pkgs.pinentry-curses;
    };
  };

  # Disable vim as the default editor to avoid conflicts
  programs.vim.defaultEditor = false;

  # Enable OpenSSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # Secure by default, use keys
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Sudo rules
  security.sudo = {
    # security.sudo.wheelNeedsPassword = false;
    extraConfig = ''
      Defaults env_keep += "EDITOR VISUAL SUDO_EDITOR"
    '';
  };
}
