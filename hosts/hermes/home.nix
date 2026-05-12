{
  pkgs,
  ...
}:
let
  hermesPkg = pkgs.llm-agents.hermes-agent;
  allDeps = hermesPkg.propagatedBuildInputs;
  hermesPython = builtins.elemAt allDeps (builtins.length allDeps - 1);
  pythonEnv = hermesPython.withPackages (_: builtins.filter (p: p != hermesPython) allDeps);
in
{
  xdg.configFile."systemd/user/hermes-gateway.service.d/nix-deps.conf".text = ''
    [Service]
    Environment="PYTHONPATH=${pythonEnv}/${hermesPython.sitePackages}"
  '';
}
