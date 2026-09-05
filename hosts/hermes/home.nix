# Host: hermes (NixOS x86_64 Proxmox LXC server).
# Registry key: flake.modules.homeManager.hermes-home
# Configures: hermes-agent's PYTHONPATH and systemd unit environment overrides.
_: {
  flake.modules.homeManager.hermes-home =
    {
      pkgs,
      lib,
      ...
    }:
    let
      hermesPkg = pkgs.llm-agents.hermes-agent;
      allDeps = hermesPkg.propagatedBuildInputs;
      hermesPython = lib.last allDeps;
      # Exclude hermesPython itself, the bundled aiosqlite (replaced below with
      # the exact 0.22.1 pin platform.matrix requires), and the bundled
      # python-olm (replaced below with an override allowing its known-vuln
      # olm) — keeping the stock copies would collide in buildEnv.
      pythonDeps = lib.filter (
        p:
        p != hermesPython
        && !(lib.elem (p.pname or null) [
          "aiosqlite"
          "python-olm"
        ])
      ) allDeps;
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
        Environment="PATH=/etc/profiles/per-user/groot/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
        Environment="MATRIX_E2EE_MODE=optional"
        Environment="MATRIX_REQUIRE_MENTION=false"
        Environment="MATRIX_ALLOW_ALL_USERS=true"
      '';
      xdg.configFile."systemd/user/hermes-gateway-coding-local.service.d/nix-deps.conf".text = ''
        [Service]
        Environment="PYTHONPATH=${hermesPkg}/${hermesPython.sitePackages}:${pythonEnv}/${hermesPython.sitePackages}"
        Environment="PATH=/etc/profiles/per-user/groot/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
        Environment="AGENT_BROWSER_EXECUTABLE_PATH=/etc/profiles/per-user/groot/bin/chromium"
        Environment="CHROMIUM_FLAGS=--no-sandbox --disable-gpu"
        Environment="MATRIX_E2EE_MODE=optional"
        Environment="MATRIX_REQUIRE_MENTION=false"
        Environment="MATRIX_ALLOW_ALL_USERS=true"
      '';
    };
}
