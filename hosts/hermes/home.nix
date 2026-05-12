{
  pkgs,
  ...
}:
let
  hermesPkg = pkgs.llm-agents.hermes-agent;
  allDeps = hermesPkg.propagatedBuildInputs;
  hermesPython = builtins.elemAt allDeps (builtins.length allDeps - 1);
  pythonDeps = builtins.filter (p: p != hermesPython) allDeps;
  pythonEnv = hermesPython.withPackages (
    _:
    pythonDeps
    ++ [
      hermesPython.pkgs.python-olm
      hermesPython.pkgs.pycryptodome
    ]
  );
in
{
  xdg.configFile."systemd/user/hermes-gateway.service.d/nix-deps.conf".text = ''
    [Service]
    Environment="PYTHONPATH=${pythonEnv}/${hermesPython.sitePackages}"
  '';
}
