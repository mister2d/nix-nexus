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
      home.packages = [ pkgs.ssh-tpm-agent ];

      # gpg-agent no longer serves SSH, so nothing else sets this.
      home.sessionVariables.SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-tpm-agent.sock";

      systemd.user.sockets = lib.mapAttrs (name: inst: {
        Unit.Description = "${inst.description} socket";
        Socket = {
          ListenStream = "%t/${name}.sock";
          SocketMode = "0600";
          Service = "${name}.service";
        };
        Install.WantedBy = [ "sockets.target" ];
      }) instances;

      systemd.user.services = lib.mapAttrs (name: inst: {
        Unit = {
          Description = inst.description;
          Requires = [ "${name}.socket" ];
        };
        Service = {
          Type = "simple";
          # The agent exits non-zero if its key directory is absent, which on a
          # fresh host is the state before any key has been generated.
          ExecStartPre = "${lib.getExe' pkgs.coreutils "mkdir"} -p -m 0700 ${inst.keyDir}";
          ExecStart = "${bin} --key-dir ${inst.keyDir}";
          Environment = [ "SSH_TPM_AUTH_SOCK=%t/${name}.sock" ];
          SuccessExitStatus = 2;
        };
      }) instances;
    };
}
