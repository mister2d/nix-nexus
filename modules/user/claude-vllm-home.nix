# Registry key: flake.modules.homeManager.user-claude-vllm-home
# Configures: the claude-vllm launcher (Claude Code via the Bifrost gateway to petunia's vLLM).
# Imported by: modules/user/home.nix (user-home).
_: {
  flake.modules.homeManager.user-claude-vllm-home =
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "claude-vllm";
          runtimeInputs = [ pkgs.coreutils ];
          text = builtins.readFile ./claude-vllm.sh;
        })
      ];
    };
}
