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
        hermes-agent = agentPkgs.hermes-agent.overridePythonAttrs (old: {
          makeWrapperArgs = (old.makeWrapperArgs or [ ]) ++ [
            "--set"
            "PYTHONPATH"
            (lib.makeSearchPath "lib/python3.13/site-packages" (old.propagatedBuildInputs or [ ]))
          ];
        });
      };
    })
  ];
}
