# Host: avina (NixOS x86_64 Proxmox LXC server).
# Registry key: flake.modules.nixos.matrix-pin-stable
# Configures: pins matrix-synapse, MAS, LiveKit, element, and postgresql to nixpkgs-stable.
# Imported by: modules/flake/nixos-avina.nix.
_: {
  flake.modules.nixos.matrix-pin-stable =
    { pkgs, inputs, ... }:
    {
      nixpkgs.overlays = [
        (_final: _prev: {
          inherit (inputs.pkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system})
            matrix-synapse-unwrapped
            matrix-authentication-service
            livekit
            lk-jwt-service
            element-web
            element-call
            postgresql_16
            ;
        })
      ];
    };
}
