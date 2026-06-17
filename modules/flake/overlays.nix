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

          # PyO3 0.24.x caps at Python 3.13; use stable ABI only for 3.14+
          pydantic-core =
            if builtins.compareVersions (pyPrev.python.pythonVersion or "0") "3.14" >= 0 then
              pyPrev.pydantic-core.overridePythonAttrs (old: {
                env = (old.env or { }) // {
                  PYO3_USE_ABI3_FORWARD_COMPATIBILITY = "1";
                };
              })
            else
              pyPrev.pydantic-core;
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
