{ ... }:
{
  # ============================================================================
  # Matrix Aspect: The Neural Hub
  # ============================================================================

  den.aspects.matrix-aspect = {
    nixos = { config, lib, ... }:
      let
        siteConfig = import ./_hw/avina/site-config.nix;
      in
      {
        imports = [
          ./_matrix/options.nix
          ./_matrix/versions.nix
          ./_matrix/synapse.nix
          ./_matrix/database.nix
          ./_matrix/mas.nix
          ./_matrix/livekit.nix
          ./_matrix/element.nix
          ./_matrix/element-call.nix
          ./_matrix/haproxy.nix
          ./_matrix/vault-secrets.nix
        ];

        matrix = siteConfig;
      };
  };
}
