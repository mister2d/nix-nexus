{ config, pkgs, ... }:

{
  security.rtkit.enable = true;
  security.polkit.enable = true;
  
  # Custom Certificate Authority
  # Place your int_cert.crt in the 'certs' directory at the root of the repo
  security.pki.certificateFiles = [
    ../../certs/int_cert.crt
  ];
  
  # Enable OpenSSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # Secure by default, use keys
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Enable GPG Agent
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-curses;
  };

  # Sudo rules
  # security.sudo.wheelNeedsPassword = false;
}
