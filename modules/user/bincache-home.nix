# Registry key: flake.modules.homeManager.user-bincache-home
# Configures: the common builder key (sops-nix, age key in the user's config dir) and the bincache
#   post-build hook script at stable paths under the home directory, for the root nix daemon's
#   /etc/nix/nix.conf, which Home Manager cannot manage. See docs/non-nixos.md.
# Imported by: hosts/dualie/home.nix (dualie-home).
_: {
  flake.modules.homeManager.user-bincache-home =
    {
      config,
      pkgs,
      lib,
      inputs,
      ...
    }:
    let
      # sops-nix links each secret at <defaultSymlinkPath>/<name>.
      keyFile = "${config.sops.defaultSymlinkPath}/builder-key";
      pushHook = import ../../lib/bincache-push.nix {
        inherit pkgs lib keyFile;
        nix = pkgs.nixVersions.nix_2_35;
      };
    in
    {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];

      sops = {
        # Generated once on the host: age-keygen -o ~/.config/sops/age/keys.txt
        age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
        defaultSopsFormat = "yaml";
        secrets.builder-key = {
          sopsFile = ../../secrets/common.yaml;
          key = "builder-key";
        };
      };

      # Stable path for post-build-hook in /etc/nix/nix.conf.
      home.file.".local/share/nix-nexus/bincache-push".source = pushHook;
    };
}
