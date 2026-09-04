# SSH client defaults for ddukes.
#
# Host-specific blocks stay hand-managed under ~/.ssh/config.d/. Only the
# global defaults live here, so per-host opt-ins (agent forwarding, jump
# hosts, forced commands) are edited without a rebuild.
_: {
  flake.modules.homeManager.user-ssh = _: {
    programs.ssh = {
      enable = true;

      # The module's legacy default block is deprecated upstream; every value
      # relied on here is declared explicitly under settings."*" instead.
      enableDefaultConfig = false;

      # Emitted ahead of the Host * block, so config.d entries take precedence
      # for any directive they set — ssh keeps the first value it obtains.
      includes = [ "config.d/*.conf" ];

      settings."*" = {
        # Agent forwarding is opt-in per host. Forwarding to every host lets
        # any of them use every key the agent holds, for the life of the
        # connection — which is precisely what a per-key agent socket exists
        # to prevent.
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
