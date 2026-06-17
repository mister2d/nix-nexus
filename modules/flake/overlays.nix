{
  inputs,
  lib,
  ...
}:
{
  flake.overlays = {
    # Global Build Fixes: fix failing builds in upstream dependencies
    buildFixes = _: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_: pyPrev: {
          # Update mcp to satisfy requirements of latest mcp-servers-nix
          # We must use the source from unstable but keep the local interpreter
          mcp = pyPrev.mcp.overridePythonAttrs (old: {
            inherit
              ((import inputs.nixpkgs-unstable {
                inherit (prev.stdenv.hostPlatform) system;
                config.allowUnfree = true;
              }).python3Packages.mcp
              )
              src
              version
              ;
            propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ pyPrev.pyjwt ];
          });

          mcp-nixos = pyPrev.mcp-nixos.overridePythonAttrs (_old: {
            doCheck = false;
          });

          aioboto3 = pyPrev.aioboto3.overridePythonAttrs (_old: {
            doCheck = false;
            dontCheck = true;
            doInstallCheck = false;
            checkPhase = "true";
            pytestCheckPhase = "true";
          });

          eventlet = pyPrev.eventlet.overridePythonAttrs (_old: {
            doCheck = false;
          });

          # pydantic-core 2.33.2 uses PyO3 0.24.1 which caps at Python 3.13.
          # For Python 3.14+ we pull the source from nixpkgs-unstable (2.41.5)
          # which has proper Python 3.14 support, and upgrade pydantic to match.
          pydantic-core =
            let
              isPy314Plus = builtins.compareVersions (pyPrev.python.pythonVersion or "0") "3.14" >= 0;
              unstablePy314 =
                (import inputs.nixpkgs-unstable {
                  inherit (prev.stdenv.hostPlatform) system;
                  config.allowUnfree = true;
                }).python314Packages;
            in
            if isPy314Plus then
              pyPrev.pydantic-core.overridePythonAttrs (_old: {
                inherit (unstablePy314.pydantic-core) version src cargoDeps;
              })
            else
              pyPrev.pydantic-core;

          pydantic =
            let
              isPy314Plus = builtins.compareVersions (pyPrev.python.pythonVersion or "0") "3.14" >= 0;
              unstablePy314 =
                (import inputs.nixpkgs-unstable {
                  inherit (prev.stdenv.hostPlatform) system;
                  config.allowUnfree = true;
                }).python314Packages;
            in
            if isPy314Plus then
              pyPrev.pydantic.overridePythonAttrs (_old: {
                inherit (unstablePy314.pydantic) version src;
              })
            else
              pyPrev.pydantic;
        })
      ];
    };

    # Patched MCP overlay that includes the python build fixes
    mcp = lib.composeManyExtensions [
      inputs.self.overlays.buildFixes
      inputs.mcp-servers-nix.overlays.default
    ];
  };
}
