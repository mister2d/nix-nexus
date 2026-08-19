# TPM-sealed SSH keys, served by two isolated ssh-tpm-agent instances.
#
# The split is the whole point: a socket forwarded into a sandbox must not be
# able to reach the personal key. ssh-tpm-agent scopes its key set by
# --key-dir, so one instance per socket is the only hard boundary — per-key
# confirmation would still let a guest *use* a key, merely with a prompt.
#
#   ssh-tpm-agent     ~/.ssh/tpm      interactive ssh, Vault-cert deploys
#   permafrost-agent  ~/.ssh/agents   forwarded to permafrost-* guests only
#
# Each instance loads only .tpm files from its directory, so plain keys left
# alongside them are ignored.
#
# The keys carry no PIN. Two constraints force that, and both are load-bearing:
#
#   * The agent is a daemon with no tty, so any PIN must come from an askpass.
#     ssh-tpm-agent only probes FHS paths (/usr/lib/ssh/gnome-ssh-askpass,
#     /usr/bin/ksshaskpass, ...) which do not exist here, and these hosts are
#     driven headless, so no GUI prompt can be answered anyway.
#   * Caching needs the kernel keyctl helpers. /sbin/request-key is absent, and
#     the agent logs "kernel is missing the keyctl executable helpers" and
#     caches nothing — so a PIN would be demanded on every signature, not once
#     per login.
#
# Security rests on the TPM instead: the private half never leaves the chip, so
# a key cannot be copied off the host. Reintroducing a PIN means solving both
# points above first.
#
# Group membership is granted by nix-nexus.tpm2.users, but the systemd user
# manager only picks it up when it restarts — a full logout or reboot. Until
# then these units fail with "open /dev/tpmrm0: permission denied".
_: {
  flake.modules.homeManager.user-ssh-tpm-agent =
    {
      pkgs,
      config,
      lib,
      ...
    }:

    let
      bin = lib.getExe' pkgs.ssh-tpm-agent "ssh-tpm-agent";

      instances = {
        ssh-tpm-agent = {
          keyDir = "${config.home.homeDirectory}/.ssh/tpm";
          description = "TPM-sealed SSH agent (personal)";
        };
        permafrost-agent = {
          keyDir = "${config.home.homeDirectory}/.ssh/agents";
          description = "TPM-sealed SSH agent (permafrost guests)";
        };
      };
    in

    {
      home = {
        packages = [ pkgs.ssh-tpm-agent ];

        # gpg-agent no longer serves SSH, so nothing else sets this. Both are
        # needed and reach different places: home.sessionVariables is sourced
        # by login shells, while graphical terminals inherit from the systemd
        # user manager, which only reads environment.d.
        sessionVariables.SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-tpm-agent.sock";

        # Both targets are generated at runtime on each host and cannot live in
        # the store, hence mkOutOfStoreSymlink. Each host resolves to its own
        # key, since a TPM key cannot be shared.
        file = {
          # ~/.ssh/id_ecdsa is in ssh's default identity list, so naming the
          # public half canonically means the key is found with no client
          # config at all — including under IdentitiesOnly, which lists exactly
          # those default paths and would otherwise offer nothing. It pairs
          # with the already-canonical ~/.ssh/id_ecdsa-cert.pub.
          #
          # Only the public half moves. The sealed key stays in its own
          # directory: --key-dir recurses, so a key-dir of ~/.ssh would pull in
          # ~/.ssh/agents too and collapse the two agents into one.
          ".ssh/id_ecdsa.pub".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.ssh/tpm/id_ecdsa_personal.pub";

          # ssh-tpm-agent reads certificates only from its own --key-dir, while
          # renewals are written to the canonical path.
          ".ssh/tpm/id_ecdsa_personal-cert.pub".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.ssh/id_ecdsa-cert.pub";
        };
      };

      systemd.user = {
        sessionVariables.SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-tpm-agent.sock";

        sockets = lib.mapAttrs (name: inst: {
          Unit.Description = "${inst.description} socket";
          Socket = {
            ListenStream = "%t/${name}.sock";
            SocketMode = "0600";
            Service = "${name}.service";
          };
          Install.WantedBy = [ "sockets.target" ];
        }) instances;

        services = lib.mapAttrs (name: inst: {
          Unit = {
            Description = inst.description;
            Requires = [ "${name}.socket" ];
          };
          Service = {
            Type = "simple";
            # The agent exits non-zero if its key directory is absent, which on
            # a fresh host is the state before any key has been generated.
            ExecStartPre = "${lib.getExe' pkgs.coreutils "mkdir"} -p -m 0700 ${inst.keyDir}";
            ExecStart = "${bin} --key-dir ${inst.keyDir}";
            Environment = [ "SSH_TPM_AUTH_SOCK=%t/${name}.sock" ];
            SuccessExitStatus = 2;
          };
        }) instances;
      };
    };
}
