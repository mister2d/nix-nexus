{ ... }:
{
  imports = [
    ./synapse.nix
    ./database.nix
    ./mas.nix
    ./coturn.nix
    ./livekit.nix
    ./element.nix
    ./haproxy.nix
    ./consul-template-certs.nix
  ];
}
