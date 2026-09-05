# Helper: builds a setup hook that provides a writable HOME for versionCheckHook.
# Called by: hosts/hermes/llm-agents-overlay.nix.
{
  lib,
  makeSetupHook,
}:

makeSetupHook {
  name = "version-check-home-hook";
  passthru.hideFromDocs = true;
  meta = {
    description = "Setup hook that provides a writable HOME for versionCheckHook";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
} ./version-check-home.sh
