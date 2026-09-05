# Host: hermes (NixOS x86_64 Proxmox LXC server).
# Registry key: flake.modules.nixos.llm-agents-hermes
# Configures: overrides pkgs.llm-agents.hermes-agent with the lib/hermes-agent vendor and context-mode-hermes.
# Imported by: modules/flake/nixos-hermes.nix.
_: {
  flake.modules.nixos.llm-agents-hermes =
    {
      pkgs,
      inputs,
      lib,
      ...
    }:
    let
      agentPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
      # llm-agents.nix has not packaged hermes-agent v2026.8.3 yet; vendor it
      # here with a graft for the upstream plugin-manifest packaging
      # regression (see lib/hermes-agent/package.nix).
      versionCheckHomeHook =
        pkgs.callPackage ../../lib/hermes-agent/version-check-home-hook/package.nix
          { };
      hermesAgentBase = pkgs.callPackage ../../lib/hermes-agent/package.nix {
        inherit versionCheckHomeHook;
      };
      # Computed from the pre-override derivation so the plugin package does
      # not close over the overridden hermes-agent's own build attrs (that
      # self-reference deadlocks nixpkgs's cross-python dependency check).
      deps = hermesAgentBase.propagatedBuildInputs;
      hermesPython = lib.last deps;
      contextModeHermes = hermesPython.pkgs.callPackage ../../lib/context-mode-hermes.nix {
        pythonPackages = hermesPython.pkgs;
      };
      newDeps = [ contextModeHermes ] ++ deps;
    in
    {
      nixpkgs.overlays = [
        (_final: _prev: {
          llm-agents = agentPkgs // {
            hermes-agent = hermesAgentBase.overridePythonAttrs (old: {
              propagatedBuildInputs = newDeps;
              makeWrapperArgs = (old.makeWrapperArgs or [ ]) ++ [
                "--set"
                "PYTHONPATH"
                (lib.makeSearchPath hermesPython.sitePackages newDeps)
              ];
            });
          };
        })
      ];
    };
}
