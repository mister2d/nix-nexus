# Host: petunia (NixOS x86_64 workstation).
# Registry key: modules.nixos.hm-agent-petunia
# Composes: core-home-manager, user-agent-home.
_: {
  modules.nixos.hm-agent-petunia =
    { homeManagerModules, nixosModules, ... }:
    {
      imports = [ nixosModules.core-home-manager ];
      home-manager.users.agent.imports = [ homeManagerModules.user-agent-home ];
    };
}
