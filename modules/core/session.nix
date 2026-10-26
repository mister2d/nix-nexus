# Registry key: flake.modules.nixos.core-session
# Configures: XDG base directory session variables for every login session (pam_env).
# Imported by: profiles/server/default.nix (server-default), profiles/workstation/default.nix (workstation-default).
_: {
  flake.modules.nixos.core-session = _: {
    environment.sessionVariables = {
      XDG_CONFIG_HOME = "@{HOME}/.config";
      XDG_DATA_HOME = "@{HOME}/.local/share";
      XDG_STATE_HOME = "@{HOME}/.local/state";
      XDG_CACHE_HOME = "@{HOME}/.cache";
    };
  };
}
