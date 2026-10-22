# Registry key: flake.modules.nixos.core-nix-signing
# Configures: signing of locally built store paths with the common builder key (sops),
#   and a post-build hook that pushes them to the internal binary cache.
# Imported by: profiles/server/default.nix (server-default), profiles/workstation/default.nix (workstation-default).
# Options: nix-nexus.nix.signing.enable
_: {
  flake.modules.nixos.core-nix-signing =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.nix-nexus.nix.signing;
      bincache = import ../../lib/bincache.nix;

      pushHook = pkgs.writeShellScript "bincache-push" ''
        set -u
        [ -n "''${OUT_PATHS:-}" ] || exit 0
        # A failed push never fails the build.
        ${pkgs.coreutils}/bin/timeout 120 \
          ${config.nix.package}/bin/nix copy --to ${lib.escapeShellArg bincache.url} $OUT_PATHS \
          || echo "bincache-push: push failed, continuing" >&2
        exit 0
      '';
    in
    {
      options.nix-nexus.nix.signing.enable = lib.mkEnableOption ''
        signing of locally built paths with the common builder key from secrets/common.yaml
        and pushing them to the internal binary cache. Requires secrets/common.yaml to exist
      '';

      config = lib.mkIf cfg.enable {
        sops = {
          # Defaults for hosts without a per-host file; core-sops overrides them when it is active.
          age.sshKeyPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];
          gnupg.sshKeyPaths = lib.mkDefault [ ];
          secrets.builder-key = {
            sopsFile = ../../secrets/common.yaml;
            format = "yaml";
            key = "builder-key";
            owner = "root";
            mode = "0400";
          };
        };

        nix.settings = {
          secret-key-files = [ config.sops.secrets.builder-key.path ];
          post-build-hook = "${pushHook}";
        };
      };
    };
}
