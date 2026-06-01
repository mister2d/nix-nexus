_: {
  flake.modules.nixos.services-matrix-default =
    { nixosModules, ... }:
    {
      imports = [
        nixosModules.services-matrix-versions
        nixosModules.services-matrix-synapse
        nixosModules.services-matrix-database
        nixosModules.services-matrix-mas
        nixosModules.services-matrix-livekit
        nixosModules.services-matrix-element
        nixosModules.services-matrix-element-call
        nixosModules.services-matrix-haproxy
        nixosModules.services-matrix-vault-secrets
      ];
    };
}
