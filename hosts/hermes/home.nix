{
  pkgs,
  lib,
  ...
}:
let
  hermesPkg = pkgs.llm-agents.hermes-agent;
  pythonPath = lib.makeSearchPath "lib/python3.13/site-packages" (
    hermesPkg.propagatedBuildInputs or [ ]
  );
in
{
  xdg.configFile."systemd/user/hermes-gateway.service.d/nix-deps.conf".text = ''
    [Service]
    Environment="PYTHONPATH=${pythonPath}"
  '';
}
