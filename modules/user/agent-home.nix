# Registry key: flake.modules.homeManager.user-agent-home
# Configures: Home Manager profile for the agent identity: bash, tmux, and herdr.
# Imported by: hosts/sweet16/agent-hm.nix (hm-agent-sweet16), hosts/petunia/agent-hm.nix (hm-agent-petunia).
# The profile carries no secrets and no path to the TPM. The assertions fail the build if the
# ssh-tpm-agent socket, the Vault token helper, or an SSH agent socket variable is configured.
_: {
  flake.modules.homeManager.user-agent-home =
    {
      config,
      lib,
      homeManagerModules,
      ...
    }:
    {
      imports = [
        homeManagerModules.user-bash
        homeManagerModules.user-terminal-home
        homeManagerModules.user-herdr-home
        homeManagerModules.user-xdg
      ];

      home.stateVersion = "25.11";

      assertions = [
        {
          assertion =
            !(config.systemd.user.sockets ? ssh-tpm-agent) && !(config.systemd.user.sockets ? permafrost-agent);
          message = "user-agent-home must not run an ssh-tpm-agent instance.";
        }
        {
          assertion = !(config.home.file ? ".vault");
          message = "user-agent-home must not configure the Vault token helper.";
        }
        {
          assertion = !(config.home.sessionVariables ? SSH_AUTH_SOCK);
          message = "user-agent-home must not export SSH_AUTH_SOCK.";
        }
        {
          assertion = lib.all (n: !(lib.hasPrefix "TPM2" n || lib.hasPrefix "TSS2" n)) (
            builtins.attrNames config.home.sessionVariables
          );
          message = "user-agent-home must not export TPM2 or TSS2 environment variables.";
        }
      ];
    };
}
