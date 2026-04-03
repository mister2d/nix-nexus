{ ... }:
{
  imports = [
    ./versions.nix
    ./synapse.nix
    ./database.nix
    ./mas.nix
    ./livekit.nix
    ./element.nix
    ./element-call.nix
    ./haproxy.nix
    ./vault-secrets.nix
  ];
}
