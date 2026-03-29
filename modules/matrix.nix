_: {
  # ============================================================================

  den.aspects.matrix-aspect = {
    nixos = {
      imports = [
        ./_matrix/versions.nix
        ./_matrix/synapse.nix
        ./_matrix/database.nix
        ./_matrix/mas.nix
        ./_matrix/coturn.nix
        ./_matrix/livekit.nix
        ./_matrix/element.nix
        ./_matrix/element-call.nix
        ./_matrix/haproxy.nix
        ./_matrix/vault-secrets.nix
        ./_matrix/whatsapp.nix
      ];
    };
  };
}
