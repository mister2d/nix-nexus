{ ... }:
{
  imports = [
    ./synapse.nix
    ./database.nix
    ./mas.nix
    ./coturn.nix
    ./livekit.nix
    ./element.nix
    ./element-call.nix
    ./haproxy.nix
    ./consul-template-secrets.nix
  ];
}
