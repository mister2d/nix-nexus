_: {
  flake.modules.homeManager.hermes-home =
    {
      pkgs,
      ...
    }:
    let
      hermesPkg = pkgs.llm-agents.hermes-agent;
      allDeps = hermesPkg.propagatedBuildInputs;
      hermesPython = builtins.elemAt allDeps (builtins.length allDeps - 1);
      pythonDeps = builtins.filter (p: p != hermesPython) allDeps;
      olm-allowed = pkgs.olm.overrideAttrs (old: {
        meta = old.meta // {
          knownVulnerabilities = [ ];
        };
      });
      aiosqlite-updated = hermesPython.pkgs.aiosqlite.overridePythonAttrs (_old: {
        version = "0.22.1";
        src = pkgs.fetchPypi {
          pname = "aiosqlite";
          version = "0.22.1";
          hash = "sha256-BD4L140yiIwKnKkPx4izh5aEM2DIVacmKlMoExM6BlA=";
        };
      });
      pythonEnv = hermesPython.withPackages (
        _:
        pythonDeps
        ++ [
          aiosqlite-updated
          hermesPython.pkgs.aiohttp-socks
          (hermesPython.pkgs.python-olm.override { olm = olm-allowed; })
          hermesPython.pkgs.pycryptodome
          hermesPython.pkgs.unpaddedbase64
          hermesPython.pkgs.base58
        ]
      );
    in
    {
      xdg.configFile."systemd/user/hermes-gateway.service.d/nix-deps.conf".text = ''
        [Service]
        Environment="PYTHONPATH=${hermesPkg}/${hermesPython.sitePackages}:${pythonEnv}/${hermesPython.sitePackages}"
      '';
    };
}
