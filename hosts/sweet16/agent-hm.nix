# Host: sweet16 (NixOS x86_64 workstation).
# Registry key: modules.nixos.hm-agent-sweet16
# Composes: core-home-manager, user-agent-home.
_: {
  modules.nixos.hm-agent-sweet16 =
    { homeManagerModules, nixosModules, ... }:
    {
      imports = [ nixosModules.core-home-manager ];
      home-manager.users.agent.imports = [ homeManagerModules.user-agent-home ];
    };
}
