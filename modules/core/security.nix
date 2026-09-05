# Registry key: flake.modules.nixos.core-security
# Configures: polkit, rtkit, PKI trust, gnome-keyring, and gpg-agent caching.
# Imported by: profiles/server/default.nix (server-default), profiles/workstation/default.nix (workstation-default).
_: {
  flake.modules.nixos.core-security =
    { pkgs, ... }:
    let
      sevenDays = 7 * 24 * 60 * 60; # seconds
    in
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

        # gnome-keyring pulls in gcr-ssh-agent, which exports SSH_AUTH_SOCK
        # into the systemd user environment. Graphical terminals inherit from
        # there rather than from a login shell, so it silently wins over the
        # session variable and hands out an agent holding no keys. Keyring
        # credential storage is unaffected.
        gnome.gcr-ssh-agent.enable = false;

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
            default-cache-ttl = sevenDays;
            max-cache-ttl = sevenDays;
          };
        };
      };

      security.sudo.extraConfig = ''
        Defaults env_keep += "EDITOR VISUAL SUDO_EDITOR"
      '';
    };
}
