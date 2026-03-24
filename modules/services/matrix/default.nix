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
    ./vault-secrets.nix
  ];
}
