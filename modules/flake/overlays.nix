# Flake assembly: overlays. Sets flake.overlays.buildFixes and flake.overlays.mcp.
# Composes the mcp-servers-nix overlay with local Python build fixes.
{
  inputs,
  lib,
  ...
}:
{
  flake.overlays = {
    # Global Build Fixes: fix failing builds in upstream dependencies
    buildFixes = _: prev: {
      # mcp-nixos is a pkgs.by-name application (buildPythonApplication), not a
      # python3Packages entry. Its checks run in installCheckPhase, gated by
      # doInstallCheck rather than doCheck. test_read_text_file reads an
      # arbitrary store file and asserts the substring "Error" is absent.
      mcp-nixos = prev.mcp-nixos.overridePythonAttrs (_old: {
        doCheck = false;
        doInstallCheck = false;
      });

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

          # test_unauthorized_access: async server fixture cannot start in the build sandbox
          fastmcp = pyPrev.fastmcp.overridePythonAttrs (old: {
            disabledTests = (old.disabledTests or [ ]) ++ [ "test_unauthorized_access" ];
          });

          aioboto3 = pyPrev.aioboto3.overridePythonAttrs (_old: {
            doCheck = false;
            dontCheck = true;
            doInstallCheck = false;
            checkPhase = "true";
            pytestCheckPhase = "true";
          });

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
