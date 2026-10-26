# Registry key: flake.modules.homeManager.user-xdg
# Configures: Home Manager xdg base directories; exports XDG_{CACHE,CONFIG,DATA,STATE,BIN}_HOME.
# Imported by: modules/user/home.nix (user-home), modules/user/standalone-home.nix (user-standalone-home),
# modules/user/agent-home.nix (user-agent-home), hosts/avina/home.nix (avina-home), hosts/hermes/groot-hm.nix (hm-groot-hermes).
_: {
  flake.modules.homeManager.user-xdg = _: {
    xdg.enable = true;
  };
}
