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
          pinentryPackage = pkgs.pinentry-curses;

          # SSH is served by ssh-tpm-agent, so gpg-agent handles GPG only and
          # the *-cache-ttl-ssh settings no longer apply.
          #
          # gpg-agent dies with the login session, so its lifetime is the real
          # bound on the cache — these values amount to "once per session"
          # rather than a literal week, and stop signing from re-prompting at
          # the old 24h ceiling.
          settings = {
            default-cache-ttl = 604800;
            max-cache-ttl = 604800;
          };
        };
      };

      security.sudo.extraConfig = ''
        Defaults env_keep += "EDITOR VISUAL SUDO_EDITOR"
      '';
    };
}
