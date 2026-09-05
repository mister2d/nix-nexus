# Registry key: flake.modules.homeManager.user-ssh
# Configures: SSH client defaults for strict host checking, keepalive, log level.
# Imported by: modules/user/home.nix (user-home).
# Host-specific blocks stay hand-managed under ~/.ssh/config.d/.
_: {
  flake.modules.homeManager.user-ssh = _: {
    programs.ssh = {
      enable = true;

      # The module's default block is deprecated upstream. Every value
      # relied on here is declared explicitly under settings."*" instead.
      enableDefaultConfig = false;

      # Emitted ahead of the Host * block. config.d entries take precedence
      # for any directive they set, since ssh keeps the first value it obtains.
      includes = [ "config.d/*.conf" ];

      settings."*" = {
        # Agent forwarding is opt-in per host. Forwarding to every host lets
        # any of them use every key the agent holds, for the life of the
        # connection. A per-key agent socket exists precisely to prevent this.
        ForwardAgent = false;

        # accept-new trusts a host on first contact but refuses a key that
        # changes underneath it, so host substitution is caught. It also gives
        # destination-constrained keys (ssh-add -h) a known_hosts file to
        # resolve against.
        StrictHostKeyChecking = "accept-new";
        UserKnownHostsFile = "~/.ssh/known_hosts";

        ServerAliveInterval = 150;
        ServerAliveCountMax = 2;
        LogLevel = "ERROR";
      };
    };
  };
}
