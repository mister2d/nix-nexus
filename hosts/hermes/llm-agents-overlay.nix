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
      # Computed from the pre-override derivation so the plugin package does
      # not close over the overridden hermes-agent's own build attrs (that
      # self-reference deadlocks nixpkgs's cross-python dependency check).
      deps = agentPkgs.hermes-agent.propagatedBuildInputs;
      hermesPython = builtins.elemAt deps (builtins.length deps - 1);
      contextModeHermes = hermesPython.pkgs.callPackage ../../lib/context-mode-hermes.nix {
        pythonPackages = hermesPython.pkgs;
      };
      newDeps = [ contextModeHermes ] ++ deps;
    in
    {
      nixpkgs.overlays = [
        (_final: _prev: {
          llm-agents = agentPkgs // {
            hermes-agent = agentPkgs.hermes-agent.overridePythonAttrs (old: {
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
