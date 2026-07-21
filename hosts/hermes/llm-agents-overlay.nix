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
    in
    {
      nixpkgs.overlays = [
        (_final: _prev: {
          llm-agents = agentPkgs // {
            hermes-agent = agentPkgs.hermes-agent.overridePythonAttrs (
              old:
              let
                deps = old.propagatedBuildInputs or [ ];
                hermesPython = builtins.elemAt deps (builtins.length deps - 1);
              in
              {
                makeWrapperArgs = (old.makeWrapperArgs or [ ]) ++ [
                  "--set"
                  "PYTHONPATH"
                  (lib.makeSearchPath hermesPython.sitePackages deps)
                ];
              }
            );
          };
        })
      ];
    };
}
