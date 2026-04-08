{ ... }:
{
  # ============================================================================
  # Security Aspect: Defensive Posture & Trust Root
  # ============================================================================

  den.aspects.security-aspect = {
    nixos = { pkgs, ... }: {
      security = {
        rtkit.enable = true;
        polkit.enable = true;
        pki.certificateFiles = [ ../certs/int_cert.crt ];
        sudo.extraConfig = ''
          Defaults env_keep += "EDITOR VISUAL SUDO_EDITOR"
        '';
      };

      services = {
        gnome.gnome-keyring.enable = true;
        pcscd.enable = true;
        udev.packages = [ pkgs.yubikey-personalization ];
        openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            PermitRootLogin = "prohibit-password";
          };
        };
      };

      programs = {
        fuse.userAllowOther = true;
        dconf.enable = true;
        gnupg.agent = {
          enable = true;
          enableSSHSupport = true;
          pinentryPackage = pkgs.pinentry-curses;
          settings = {
            default-cache-ttl = 28800;
            max-cache-ttl = 86400;
            default-cache-ttl-ssh = 28800;
            max-cache-ttl-ssh = 86400;
          };
        };
      };
    };
  };
}
