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
}
