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
      pythonEnv = hermesPython.withPackages (
        _:
        pythonDeps
        ++ [
          hermesPython.pkgs.aiohttp-socks
        ]
      );
    in
    {
      xdg.configFile."systemd/user/hermes-gateway.service.d/nix-deps.conf".text = ''
        [Service]
        EnvironmentFile=-%h/.env
        Environment="PYTHONPATH=${hermesPkg}/${hermesPython.sitePackages}:${pythonEnv}/${hermesPython.sitePackages}"
        Environment="PATH=/etc/profiles/per-user/groot/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
        Environment="MATRIX_E2EE_MODE=off"
        Environment="MATRIX_REQUIRE_MENTION=false"
      '';
      xdg.configFile."systemd/user/hermes-gateway-coding-local.service.d/nix-deps.conf".text = ''
        [Service]
        EnvironmentFile=-%h/.env
        Environment="PYTHONPATH=${hermesPkg}/${hermesPython.sitePackages}:${pythonEnv}/${hermesPython.sitePackages}"
        Environment="PATH=/etc/profiles/per-user/groot/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
        Environment="AGENT_BROWSER_EXECUTABLE_PATH=/etc/profiles/per-user/groot/bin/chromium"
        Environment="CHROMIUM_FLAGS=--no-sandbox --disable-gpu"
        Environment="MATRIX_E2EE_MODE=off"
        Environment="MATRIX_REQUIRE_MENTION=false"
      '';
    };
}
