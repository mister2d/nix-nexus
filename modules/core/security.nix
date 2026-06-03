_: {
  flake.modules.nixos.core-security =
    { pkgs, ... }:
    {
      security = {
        rtkit.enable = true;
        polkit.enable = true;

        pki.certificateFiles = [
          ../../certs/int_cert.crt
        ];
      };

      services = {
        gnome.gnome-keyring.enable = true;

        pcscd.enable = true;
        udev.packages = [ pkgs.yubikey-personalization ];
      };

      programs = {
        fuse.userAllowOther = true;
        dconf.enable = true;
        vim.defaultEditor = false;

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

      security.sudo.extraConfig = ''
        Defaults env_keep += "EDITOR VISUAL SUDO_EDITOR"
      '';
    };
}
